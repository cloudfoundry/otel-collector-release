package loggregatorreceiver

import (
	"context"
	"errors"
	"net"
	"sync"

	"code.cloudfoundry.org/go-loggregator/v9/rpc/loggregator_v2"
	"go.opentelemetry.io/collector/component"
	"go.opentelemetry.io/collector/consumer"
	"go.opentelemetry.io/collector/pdata/pcommon"
	"go.opentelemetry.io/collector/pdata/pmetric"
	"go.opentelemetry.io/collector/receiver"
	"go.opentelemetry.io/collector/receiver/receiverhelper"
	"go.uber.org/zap"
	"google.golang.org/grpc"
)

type loggregatorReceiver struct {
	cfg      *Config
	serverV1 *net.Listener
	serverV2 *grpc.Server

	nextTraces  consumer.Traces
	nextMetrics consumer.Metrics
	nextLogs    consumer.Logs
	shutdownWG  sync.WaitGroup

	obsrepV1 *receiverhelper.ObsReport
	obsrepV2 *receiverhelper.ObsReport

	set *receiver.CreateSettings

	loggregator_v2.UnimplementedIngressServer
}

func newLoggregatorReceiver(cfg *Config, set *receiver.CreateSettings) (*loggregatorReceiver, error) {
	obsrepV1, err := receiverhelper.NewObsReport(receiverhelper.ObsReportSettings{
		ReceiverID:             set.ID,
		Transport:              "loggregator v1",
		ReceiverCreateSettings: *set,
	})
	if err != nil {
		return nil, err
	}
	obsrepV2, err := receiverhelper.NewObsReport(receiverhelper.ObsReportSettings{
		ReceiverID:             set.ID,
		Transport:              "loggregator v2",
		ReceiverCreateSettings: *set,
	})
	if err != nil {
		return nil, err
	}

	return &loggregatorReceiver{
		cfg:         cfg,
		nextTraces:  nil,
		nextMetrics: nil,
		nextLogs:    nil,
		set:         set,
		obsrepV1:    obsrepV1,
		obsrepV2:    obsrepV2,
	}, nil
}

func (r *loggregatorReceiver) startV1Server(host component.Host) error {
	// If V1 is not enabled, nothing to start.
	if r.cfg.V1 == nil {
		return nil
	}

	return nil
}

func (r *loggregatorReceiver) startV2Server(host component.Host) error {
	// If V2 is not enabled, nothing to start.
	if r.cfg.V2 == nil {
		return nil
	}

	var err error
	if r.serverV2, err = r.cfg.V2.GRPC.ToServer(host, r.set.TelemetrySettings); err != nil {
		return err
	}

	loggregator_v2.RegisterIngressServer(r.serverV2, r)

	r.set.Logger.Info("Starting V2 server", zap.String("endpoint", r.cfg.V2.GRPC.NetAddr.Endpoint))
	var gln net.Listener
	if gln, err = r.cfg.V2.GRPC.NetAddr.Listen(); err != nil {
		return err
	}

	r.shutdownWG.Add(1)
	go func() {
		defer r.shutdownWG.Done()

		if errGrpc := r.serverV2.Serve(gln); errGrpc != nil && !errors.Is(errGrpc, grpc.ErrServerStopped) {
			r.set.ReportComponentStatus(component.NewFatalErrorEvent(errGrpc))
		}
	}()
	return nil
}

// Start runs the receiver.
func (r *loggregatorReceiver) Start(ctx context.Context, host component.Host) error {
	if err := r.startV1Server(host); err != nil {
		return err
	}
	if err := r.startV2Server(host); err != nil {
		// It's possible that a valid V1 server configuration was specified, but
		// an invalid V2 configuration. If that's the case, the successfully
		// started V1 server must be shutdown to ensure no goroutines are
		// leaked.
		return errors.Join(err, r.Shutdown(ctx))
	}
	return nil
}

// Shutdown turns off receiving.
func (r *loggregatorReceiver) Shutdown(ctx context.Context) error {
	r.shutdownWG.Wait()
	return nil
}

func (r *loggregatorReceiver) Sender(s loggregator_v2.Ingress_SenderServer) error {
	for {
		e, err := s.Recv()
		if err != nil {
			return err
		}
		r.convertAndConsumeEnvelope(e)
	}
}

func (r *loggregatorReceiver) BatchSender(s loggregator_v2.Ingress_BatchSenderServer) error {
	for {
		b, err := s.Recv()
		if err != nil {
			return err
		}
		for _, e := range b.Batch {
			r.convertAndConsumeEnvelope(e)
		}
	}
}

func (r *loggregatorReceiver) Send(_ context.Context, b *loggregator_v2.EnvelopeBatch) (*loggregator_v2.SendResponse, error) {
	for _, e := range b.Batch {
		r.convertAndConsumeEnvelope(e)
	}
	return &loggregator_v2.SendResponse{}, nil
}

// Send(context.Context, *EnvelopeBatch) (*SendResponse, error)

func (r *loggregatorReceiver) convertAndConsumeEnvelope(e *loggregator_v2.Envelope) {
	switch message := e.Message.(type) {
	case *loggregator_v2.Envelope_Counter:
		metrics := pmetric.NewMetrics()
		m := metrics.ResourceMetrics().AppendEmpty().ScopeMetrics().AppendEmpty().Metrics().AppendEmpty()
		m.SetName(message.Counter.GetName())
		dataPoint := m.SetEmptySum().DataPoints().AppendEmpty()
		dataPoint.SetDoubleValue(float64(message.Counter.GetTotal()))
		dataPoint.SetTimestamp(pcommon.Timestamp(e.GetTimestamp()))
		copyEnvelopeAttributes(dataPoint.Attributes(), e)
		obsCtx := r.obsrepV2.StartMetricsOp(context.Background())
		err := r.nextMetrics.ConsumeMetrics(obsCtx, metrics)
		r.obsrepV2.EndMetricsOp(obsCtx, "loggregator v2", metrics.DataPointCount(), err)
	case *loggregator_v2.Envelope_Gauge:
		metrics := pmetric.NewMetrics()
		m := metrics.ResourceMetrics().AppendEmpty().ScopeMetrics().AppendEmpty().Metrics().AppendEmpty()
		for name, value := range message.Gauge.GetMetrics() {
			m.SetName(name)
			dataPoint := m.SetEmptyGauge().DataPoints().AppendEmpty()
			dataPoint.SetDoubleValue(value.Value)
			dataPoint.SetTimestamp(pcommon.Timestamp(e.GetTimestamp()))
			copyEnvelopeAttributes(dataPoint.Attributes(), e)
		}
		obsCtx := r.obsrepV2.StartMetricsOp(context.Background())
		err := r.nextMetrics.ConsumeMetrics(obsCtx, metrics)
		r.obsrepV2.EndMetricsOp(obsCtx, "loggregator v2", metrics.DataPointCount(), err)
	}
}

func copyEnvelopeAttributes(m pcommon.Map, e *loggregator_v2.Envelope) {
	for key, value := range e.Tags {
		m.PutStr(key, value)
	}

	if e.SourceId != "" {
		m.PutStr("source_id", e.SourceId)
	}

	if e.InstanceId != "" {
		m.PutStr("instance_id", e.InstanceId)
	}
}
