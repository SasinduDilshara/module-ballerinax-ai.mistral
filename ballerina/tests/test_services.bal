// Copyright (c) 2025 WSO2 LLC. (http://www.wso2.org).
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/test;
import ballerinax/mistral;

service /llm on new http:Listener(8080) {
    // bug: https://github.com/ballerina-platform/ballerina-library/issues/8048
    resource function post chat/completions(@http:Payload json payload)returns mistral:ChatCompletionResponse|error {
        test:assertEquals(payload.model, MINISTRAL_8B_2410);
        test:assertEquals(payload.temperature, 0.1d);
        test:assertEquals(payload.max_tokens, 100);

        json[] messages = check payload.messages.ensureType();
        mistral:UserMessage message = check (messages[0]).fromJsonWithType();
        string? content = check message.content.ensureType();
        if content is () {
            test:assertFail("Expected content in the payload");
        }

        test:assertEquals(content, getExpectedPrompt(content));
        test:assertEquals(message.role, "user");
        json[]? tools = check payload?.tools.ensureType();
        if tools is () || tools.length() == 0 {
            test:assertFail("No tools in the payload");
        }

        mistral:Tool tool = check tools[0].fromJsonWithType();
        record {} parameters = tool.'function.parameters;
        if parameters == {} {
            test:assertFail("No parameters in the expected tool in the test with content: " + content);
        }

        test:assertEquals(parameters, getExpectedParameterSchema(content));
        return getTestServiceResponse(content);
    }
}
