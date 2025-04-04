// Licensed to Elasticsearch B.V. under one or more contributor
// license agreements. See the NOTICE file distributed with
// this work for additional information regarding copyright
// ownership. Elasticsearch B.V. licenses this file to you under
// the Apache License, Version 2.0 (the "License"); you may
// not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

package mage

import (
	"fmt"

	"github.com/magefile/mage/mg"

	"github.com/elastic/lunes/dev-tools/mage/gotool"
)

// Deps contains targets related to checking dependencies
type Deps mg.Namespace

// CheckModuleTidy checks if `go mod tidy` was run before the last commit.
func (Deps) CheckModuleTidy() error {
	err := gotool.Mod.Tidy()
	if err != nil {
		return err
	}
	err = assertUnchanged("go.mod")
	if err != nil {
		return fmt.Errorf("`go mod tidy` was not called before the last commit: %w", err)
	}

	return nil
}
