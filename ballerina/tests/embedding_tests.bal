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

import ballerina/ai;
import ballerina/http;
import ballerina/test;
import ballerinax/mistral;

// The embedding vector returned by the mock embeddings service. The values are
// chosen to be exactly representable so that the `decimal` to `float` conversion
// performed by the provider is loss-less and the assertions stay deterministic.
final readonly & decimal[] testEmbeddingVector = [1.0, 2.0, 3.0, 4.0, 5.0];

// The `ai:Embedding` value expected once the provider converts the response.
final readonly & float[] expectedEmbeddingVector = [1.0, 2.0, 3.0, 4.0, 5.0];

final EmbeddingProvider embeddingProvider = check new (API_KEY, MISTRAL_EMBED, SERVICE_URL);
final EmbeddingProvider codestralEmbeddingProvider = check new (API_KEY, CODESTRAL_EMBED, SERVICE_URL);

// Builds the mock embeddings API response. The first input string acts as a
// marker that drives the various happy and error scenarios under test.
function getEmbeddingServiceResponse(json payloadJson)
        returns mistral:EmbeddingResponse|http:Response|error {
    map<json> payload = check payloadJson.ensureType();
    string model = check payload["model"].ensureType();
    test:assertTrue(model == MISTRAL_EMBED || model == CODESTRAL_EMBED,
            string `Unexpected embedding model in request: ${model}`);

    json input = payload["input"];
    string[] inputs = [];
    if input is string {
        inputs = [input];
    } else if input is json[] {
        inputs = input.'map(item => item.toString());
    } else {
        test:assertFail("The 'input' field must be a string or an array of strings");
    }

    string marker = inputs[0];
    if marker.includes("server-error") {
        return buildEmbeddingErrorResponse(500, "Internal server error");
    }
    if marker.includes("unauthorized") {
        return buildEmbeddingErrorResponse(401, "Unauthorized: invalid API key");
    }
    if marker.includes("rate-limit") {
        return buildEmbeddingErrorResponse(429, "Requests rate limit exceeded");
    }

    mistral:EmbeddingResponseData[] data = [];
    if !marker.includes("empty-data") {
        foreach int i in 0 ..< inputs.length() {
            data.push(inputs[i].includes("null-embedding")
                ? {index: i, 'object: "embedding"}
                : {index: i, 'object: "embedding", embedding: testEmbeddingVector});
        }
    }
    return {
        id: "embd-0000000000000000",
        'object: "list",
        model,
        data,
        usage: {promptTokens: 8, completionTokens: 0, totalTokens: 8}
    };
}

// Builds a non-2xx HTTP response to exercise the provider's error mapping.
function buildEmbeddingErrorResponse(int statusCode, string message) returns http:Response {
    http:Response response = new;
    response.statusCode = statusCode;
    response.setJsonPayload({message});
    return response;
}

@test:Config
function testEmbedWithTextChunk() returns ai:Error? {
    ai:TextChunk chunk = {content: "Ballerina is an open-source programming language."};
    ai:Embedding embedding = check embeddingProvider->embed(chunk);
    test:assertEquals(embedding, expectedEmbeddingVector);
}

@test:Config
function testEmbedWithTextDocument() returns ai:Error? {
    ai:TextDocument document = {content: "Mistral AI provides state-of-the-art embedding models."};
    ai:Embedding embedding = check embeddingProvider->embed(document);
    test:assertEquals(embedding, expectedEmbeddingVector);
}

@test:Config
function testEmbedWithCodestralModel() returns ai:Error? {
    ai:TextChunk chunk = {content: "public function main() {}"};
    ai:Embedding embedding = check codestralEmbeddingProvider->embed(chunk);
    test:assertEquals(embedding, expectedEmbeddingVector);
}

@test:Config
function testEmbedWithUnsupportedChunkType() {
    ai:Chunk chunk = {'type: "image", content: "https://example.com/image.png"};
    ai:Embedding|ai:Error embedding = embeddingProvider->embed(chunk);
    test:assertTrue(embedding is ai:Error);
    test:assertEquals((<ai:Error>embedding).message(),
            "Unsupported chunk type. only 'ai:TextDocument|ai:TextChunk' is supported");
}

@test:Config
function testEmbedWithEmptyResponseData() {
    ai:TextChunk chunk = {content: "empty-data"};
    ai:Embedding|ai:Error embedding = embeddingProvider->embed(chunk);
    test:assertTrue(embedding is ai:Error);
    test:assertEquals((<ai:Error>embedding).message(), "No embeddings generated for the provided chunk");
}

@test:Config
function testEmbedWithNullEmbeddingInResponse() {
    ai:TextChunk chunk = {content: "null-embedding"};
    ai:Embedding|ai:Error embedding = embeddingProvider->embed(chunk);
    test:assertTrue(embedding is ai:Error);
    test:assertEquals((<ai:Error>embedding).message(), "Unable to obtain embedding for the provided chunk");
}

@test:Config
function testEmbedWithServerError() {
    ai:TextChunk chunk = {content: "server-error"};
    ai:Embedding|ai:Error embedding = embeddingProvider->embed(chunk);
    test:assertTrue(embedding is ai:Error);
    test:assertEquals((<ai:Error>embedding).message(), "Unable to obtain embedding for the provided chunk");
}

@test:Config
function testEmbedWithUnauthorizedError() {
    ai:TextChunk chunk = {content: "unauthorized"};
    ai:Embedding|ai:Error embedding = embeddingProvider->embed(chunk);
    test:assertTrue(embedding is ai:Error);
    test:assertEquals((<ai:Error>embedding).message(), "Unable to obtain embedding for the provided chunk");
}

@test:Config
function testEmbedWithRateLimitError() {
    ai:TextChunk chunk = {content: "rate-limit"};
    ai:Embedding|ai:Error embedding = embeddingProvider->embed(chunk);
    test:assertTrue(embedding is ai:Error);
    test:assertEquals((<ai:Error>embedding).message(), "Unable to obtain embedding for the provided chunk");
}

@test:Config
function testBatchEmbedWithTextChunks() returns ai:Error? {
    ai:TextChunk[] chunks = [
        {content: "First chunk to embed."},
        {content: "Second chunk to embed."},
        {content: "Third chunk to embed."}
    ];
    ai:Embedding[] embeddings = check embeddingProvider->batchEmbed(chunks);
    test:assertEquals(embeddings.length(), 3);
    test:assertEquals(embeddings,
            [expectedEmbeddingVector, expectedEmbeddingVector, expectedEmbeddingVector]);
}

@test:Config
function testBatchEmbedWithTextDocuments() returns ai:Error? {
    ai:TextDocument[] documents = [
        {content: "First document to embed."},
        {content: "Second document to embed."}
    ];
    ai:Embedding[] embeddings = check embeddingProvider->batchEmbed(documents);
    test:assertEquals(embeddings, [expectedEmbeddingVector, expectedEmbeddingVector]);
}

@test:Config
function testBatchEmbedWithUnsupportedChunkType() {
    ai:TextChunk validChunk = {content: "A valid text chunk."};
    ai:Chunk imageChunk = {'type: "image", content: "https://example.com/image.png"};
    ai:Chunk[] chunks = [validChunk, imageChunk];
    ai:Embedding[]|ai:Error embeddings = embeddingProvider->batchEmbed(chunks);
    test:assertTrue(embeddings is ai:Error);
    test:assertEquals((<ai:Error>embeddings).message(),
            "Unsupported chunk type. only 'ai:TextChunk[]|ai:TextDocument[]' is supported");
}

@test:Config
function testBatchEmbedWithNullEmbeddingInResponse() {
    ai:TextChunk[] chunks = [
        {content: "null-embedding"},
        {content: "Another chunk to embed."}
    ];
    ai:Embedding[]|ai:Error embeddings = embeddingProvider->batchEmbed(chunks);
    test:assertTrue(embeddings is ai:Error);
    test:assertEquals((<ai:Error>embeddings).message(), "Unable to obtain embedding for the provided chunk");
}

@test:Config
function testBatchEmbedWithServerError() {
    ai:TextChunk[] chunks = [{content: "server-error"}];
    ai:Embedding[]|ai:Error embeddings = embeddingProvider->batchEmbed(chunks);
    test:assertTrue(embeddings is ai:Error);
    test:assertEquals((<ai:Error>embeddings).message(), "Unable to obtain embedding for the provided chunk");
}

@test:Config
function testEmbeddingProviderInitWithDefaultServiceUrl() {
    EmbeddingProvider|ai:Error provider = new (API_KEY, MISTRAL_EMBED);
    test:assertTrue(provider is EmbeddingProvider);
}

@test:Config
function testEmbeddingProviderInitWithInvalidServiceUrl() {
    EmbeddingProvider|ai:Error provider = new (API_KEY, MISTRAL_EMBED, "invalid service url");
    test:assertTrue(provider is ai:Error);
    test:assertEquals((<ai:Error>provider).message(), "Failed to initialize Mistral AI embedding provider");
}
