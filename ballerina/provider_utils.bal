// Copyright (c) 2025 WSO2 LLC (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
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

import ballerina/ai;
import ballerinax/mistral;

type ResponseSchema record {|
    map<json> schema;
    boolean isOriginallyJsonObject = true;
|};

const JSON_CONVERSION_ERROR = "FromJsonStringError";
const CONVERSION_ERROR = "ConversionError";
const ERROR_MESSAGE = "Error occurred while attempting to parse the response from the " +
    "LLM as the expected type. Retrying and/or validating the prompt could fix the response.";
const RESULT = "result";
const GET_RESULTS_TOOL = "getResults";
const FUNCTION = "function";
const NO_RELEVANT_RESPONSE_FROM_THE_LLM = "No relevant response from the LLM";

isolated function generateJsonObjectSchema(map<json> schema) returns ResponseSchema {
    string[] supportedMetaDataFields = ["$schema", "$id", "$anchor", "$comment", "title", "description"];

    if schema["type"] == "object" {
        return {schema};
    }

    map<json> updatedSchema = map from var [key, value] in schema.entries()
        where supportedMetaDataFields.indexOf(key) is int
        select [key, value];

    updatedSchema["type"] = "object";
    map<json> content = map from var [key, value] in schema.entries()
        where supportedMetaDataFields.indexOf(key) !is int
        select [key, value];

    updatedSchema["properties"] = {[RESULT]: content};

    return {schema: updatedSchema, isOriginallyJsonObject: false};
}

isolated function parseResponseAsType(string resp,
        typedesc<anydata> expectedResponseTypedesc, boolean isOriginallyJsonObject) returns anydata|error {
    if !isOriginallyJsonObject {
        map<json> respContent = check resp.fromJsonStringWithType();
        anydata|error result = trap respContent[RESULT].fromJsonWithType(expectedResponseTypedesc);
        if result is error {
            return handleParseResponseError(result);
        }
        return result;
    }

    anydata|error result = resp.fromJsonStringWithType(expectedResponseTypedesc);
    if result is error {
        return handleParseResponseError(result);
    }
    return result;
}

isolated function getExpectedResponseSchema(typedesc<anydata> expectedResponseTypedesc) returns ResponseSchema|ai:Error {
    // Restricted at compile-time for now.
    typedesc<json> td = checkpanic expectedResponseTypedesc.ensureType();
    return generateJsonObjectSchema(check generateJsonSchemaForTypedescAsJson(td));
}

isolated function generateChatCreationContent(ai:Prompt prompt) returns string|ai:Error {
    string[] & readonly strings = prompt.strings;
    anydata[] insertions = prompt.insertions;
    string promptStr = strings[0];
    foreach int i in 0 ..< insertions.length() {
        string str = strings[i + 1];
        anydata insertion = insertions[i];

        if insertion is ai:TextDocument {
            promptStr += insertion.content + " " + str;
            continue;
        }

        if insertion is ai:TextDocument[] {
            foreach ai:TextDocument doc in insertion {
                promptStr += doc.content  + " ";
                
            }
            promptStr += str;
            continue;
        }

        if insertion is ai:Document {
            return error ai:Error("Only Text Documents are currently supported.");
        }

        promptStr += insertion.toString() + str;
    }
    return promptStr.trim();
}

isolated function handleParseResponseError(error chatResponseError) returns error {
    string msg = chatResponseError.message();
    if msg.includes(JSON_CONVERSION_ERROR) || msg.includes(CONVERSION_ERROR) {
        return error(ERROR_MESSAGE, chatResponseError);
    }
    return chatResponseError;
}

isolated function getGetResultsToolChoice() returns mistral:ToolChoice => {
    'type: FUNCTION,
    'function: {
        name: GET_RESULTS_TOOL
    }
};

isolated function getGetResultsTool(map<json> parameters) returns mistral:Tool[]|error =>
    [
        {
            'function: {
                name: GET_RESULTS_TOOL,
                parameters: check parameters.cloneWithType(),
                strict: false,
                description: "Tool to call with the resp onse from a large language model (LLM) for a user prompt."
            }
        }
    ];

isolated function generateLlmResponse(mistral:Client llmClient, int maxTokens, MISTRAL_AI_MODEL_NAMES modelType, 
        decimal temperature, ai:Prompt prompt, typedesc<json> expectedResponseTypedesc) returns anydata|ai:Error {
    string chatContent = check generateChatCreationContent(prompt);
    ResponseSchema ResponseSchema = check getExpectedResponseSchema(expectedResponseTypedesc);
    mistral:Tool[]|error tools = getGetResultsTool(ResponseSchema.schema);
    if tools is error {
        return error("Error while generating the tool: " + tools.message());
    }

    mistral:ChatCompletionRequest request = {
        messages: [
            {
                role: "user",
                content: chatContent
            }
        ],
        model: modelType,
        tools,
        temperature,
        maxTokens,
        toolChoice: getGetResultsToolChoice()
    };

    mistral:ChatCompletionResponse|error response = llmClient->/chat/completions.post(request);
    if response is error {
        return error ai:LlmConnectionError("Error while connecting to the model", response);
    }

    mistral:ChatCompletionChoice[]? choices = response.choices;
    if choices is () || choices.length() == 0 {
        return error ai:LlmInvalidResponseError("Empty response from the model when using function call API");
    }
    mistral:AssistantMessage message = choices[0].message;

    mistral:ToolCall[]? toolCalls = message?.toolCalls;

    if toolCalls == () || toolCalls.length() == 0 {
        return error(NO_RELEVANT_RESPONSE_FROM_THE_LLM);
    }

    mistral:ToolCall tool = toolCalls[0];
    string|record{} toolArguments = tool.'function.arguments;

    if toolArguments == "" || toolArguments == {} {
        return error(NO_RELEVANT_RESPONSE_FROM_THE_LLM);
    }

    do {
        json jsonArgs = toolArguments is string ? check toolArguments.fromJsonString() : toolArguments.toJson();
        map<json>? arguments = check jsonArgs.cloneWithType();

        anydata|error res = parseResponseAsType(arguments.toJsonString(), expectedResponseTypedesc,
                ResponseSchema.isOriginallyJsonObject);
        if res is error {
            return error ai:LlmInvalidGenerationError(string `Invalid value returned from the LLM Client, expected: '${
                expectedResponseTypedesc.toBalString()}', found '${res.toBalString()}'`);
        }

        anydata|error result = res.ensureType(expectedResponseTypedesc);
        if result is error {
            return error ai:LlmInvalidGenerationError(string `Invalid value returned from the LLM Client, expected: '${
                expectedResponseTypedesc.toBalString()}', found '${(typeof response).toBalString()}'`);
        }
        
        return result;
    } on fail error e {
        return error("Invalid or malformed arguments received in function call response.", e);
    }
}

