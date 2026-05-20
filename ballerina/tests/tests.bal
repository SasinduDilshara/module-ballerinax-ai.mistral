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
import ballerina/test;

const SERVICE_URL = "http://localhost:8090/llm";
const API_KEY = "not-a-real-api-key";
const ERROR_MESSAGE = "Error occurred while attempting to parse the response from the LLM as the expected type. Retrying and/or validating the prompt could fix the response.";
const RUNTIME_SCHEMA_NOT_SUPPORTED_ERROR_MESSAGE = "Runtime schema generation is not yet supported";

final ModelProvider mistralProvider = check new (API_KEY, MINISTRAL_8B_2410,
    SERVICE_URL, maxTokens = 100, temperature = 0.1
);

@test:Config
function testGenerateMethodWithBasicReturnType() returns ai:Error? {
    int|error rating = mistralProvider->generate(`Rate this blog out of 10.
        Title: ${blog1.title}
        Content: ${blog1.content}`);
    test:assertEquals(rating, 4);
}

@test:Config
function testGenerateMethodWithBasicArrayReturnType() returns ai:Error? {
    int[]|error rating = mistralProvider->generate(`Evaluate this blogs out of 10.
        Title: ${blog1.title}
        Content: ${blog1.content}

        Title: ${blog1.title}
        Content: ${blog1.content}`);
    test:assertEquals(rating, [9, 1]);
}

@test:Config
function testGenerateMethodWithRecordReturnType() returns error? {
    Review|error result = mistralProvider->generate(`Please rate this blog out of ${"10"}.
        Title: ${blog2.title}
        Content: ${blog2.content}`);
    test:assertEquals(result, check reviewStr.fromJsonStringWithType(Review));
}

@test:Config
function testGenerateMethodWithTextDocument() returns ai:Error? {
    ai:TextDocument blog = {
        content: string `Title: ${blog1.title} Content: ${blog1.content}`
    };
    int maxScore = 10;

    int|error rating = mistralProvider->generate(`How would you rate this ${"blog"} content out of ${maxScore}. ${blog}.`);
    test:assertEquals(rating, 4);
}

type ReviewArray Review[];

@test:Config
function testGenerateMethodWithTextDocumentArray() returns error? {
    ai:TextDocument blog = {
        content: string `Title: ${blog1.title} Content: ${blog1.content}`
    };
    ai:TextDocument[] blogs = [blog, blog];
    int maxScore = 10;
    Review r = check reviewStr.fromJsonStringWithType(Review);

    ReviewArray|error result = mistralProvider->generate(`How would you rate these text blogs out of ${maxScore}. ${blogs}. Thank you!`);
    test:assertEquals(result, [r, r]);
}

@test:Config
function testGenerateMethodWithTextChunk() returns error? {
    ai:TextChunk chunk = {
        content: string `Title: ${blog1.title} Content: ${blog1.content}`
    };
    ai:TextChunk[] chunks = [chunk, chunk];
    int maxScore = 10;

    int rating = check mistralProvider->generate(`How would you rate this text chunk content out of ${maxScore}. ${chunk}.`);
    test:assertEquals(rating, 4);

    Review r = check reviewStr.fromJsonStringWithType(Review);
    ReviewArray result = check mistralProvider->generate(`How would you rate these text chunks out of ${maxScore}. ${chunks}. Thank you!`);
    test:assertEquals(result, [r, r]);
}

@test:Config
function testGenerateMethodWithImageDocumentWithBinaryData() returns ai:Error? {
    ai:ImageDocument img = {
        content: sampleBinaryData
    };

    ai:ImageDocument img2 = {
        content: sampleBinaryData,
        metadata: {
            mimeType: "image/png"
        }
    };

    string|error description = mistralProvider->generate(`Describe the following image. ${img}.`);
    test:assertTrue(description is error);
    test:assertTrue((<error>description).message().includes("Please specify the mimeType for the image document."));

    description = mistralProvider->generate(`Describe the following image. ${img2}.`);
    test:assertEquals(description, "This is a sample image description.");
}

@test:Config
function testGenerateMethodWithImageDocumentWithUrl() returns ai:Error? {
    ai:ImageDocument img = {
        content: "https://example.com/image.jpg",
        metadata: {
            mimeType: "image/jpg"
        }
    };

    string|error description = mistralProvider->generate(`Describe the image. ${img}.`);
    test:assertEquals(description, "This is a sample image description.");
}

@test:Config
function testGenerateMethodWithImageDocumentWithInvalidUrl() returns ai:Error? {
    ai:ImageDocument img = {
        content: "This-is-not-a-valid-url"
    };

    string|ai:Error description = mistralProvider->generate(`Please describe the image. ${img}.`);
    test:assertTrue(description is ai:Error);

    string actualErrorMessage = (<ai:Error>description).message();
    string expectedErrorMessage = "Must be a valid URL";
    test:assertTrue((<ai:Error>description).message().includes("Must be a valid URL"),
            string `expected '${expectedErrorMessage}', found ${actualErrorMessage}`);
}

@test:Config
function testGenerateMethodWithImageDocumentArray() returns ai:Error? {
    ai:ImageDocument img = {
        content: sampleBinaryData,
        metadata: {
            mimeType: "image/png"
        }
    };
    ai:ImageDocument img2 = {
        content: "https://example.com/image.jpg"
    };

    string[]|error descriptions = mistralProvider->generate(
        `Describe the following ${"2"} images. ${<ai:ImageDocument[]>[img, img2]}.`);
    test:assertEquals(descriptions, ["This is a sample image description.", "This is a sample image description."]);
}

@test:Config
function testGenerateMethodWithTextAndImageDocumentArray() returns ai:Error? {
    ai:ImageDocument img = {
        content: sampleBinaryData,
        metadata: {
            mimeType: "image/png"
        }
    };
    ai:TextDocument blog = {
        content: string `Title: ${blog1.title} Content: ${blog1.content}`
    };

    string[]|error descriptions = mistralProvider->generate(
        `Please describe the following image and the doc. ${<ai:Document[]>[img, blog]}.`);
    test:assertEquals(descriptions, ["This is a sample image description.", "This is a sample doc description."]);
}

@test:Config
function testGenerateMethodWithImageDocumentsandTextDocuments() returns ai:Error? {
    ai:ImageDocument img = {
        content: sampleBinaryData,
        metadata: {
            mimeType: "image/png"
        }
    };
    ai:TextDocument blog = {
        content: string `Title: ${blog1.title} Content: ${blog1.content}`
    };

    string[]|error descriptions = mistralProvider->generate(
        `${"Describe"} the following ${"text"} ${"document"} and image document. ${img}${blog}`);
    test:assertEquals(descriptions, ["This is a sample image description.", "This is a sample doc description."]);
}

@test:Config
function testGenerateMethodWithUnsupportedDocument() returns ai:Error? {
    ai:Document doc = {
        'type: "audio",
        content: "dummy-data"
    };

    string[]|error descriptions = mistralProvider->generate(`What is the content in this document. ${doc}.`);
    test:assertTrue(descriptions is error);
    test:assertTrue((<error>descriptions).message().includes("Only text, image and file documents are supported."));
}

@test:Config
function testFileDocument() returns ai:Error? {
    ai:FileDocument pdf = {
        content: {fileId: "<file-id>"}
    };

    ai:FileDocument pdf2 = {
        content: sampleBinaryData
    };

    ai:FileDocument pdf3 = {
        content: "https://sampleurl.com"
    };

    ai:FileDocument pdf4 = {
        metadata: {
            fileName: "sample.pdf"
        },
        content: "https://sampleurl.com"
    };

    ai:FileDocument pdf5 = {
        content: "<invalid-url>"
    };

    string|error description = mistralProvider->generate(`Describe the following pdf content. ${pdf4}.`);
    test:assertEquals(description, "This is a sample pdf description.");

    string[]|error descriptions = mistralProvider->generate(`Describe the following pdf files. ${<ai:FileDocument[]>[pdf3, pdf3]}.`);
    test:assertEquals(descriptions, ["This is a sample pdf description.", "This is a sample pdf description."]);

    description = mistralProvider->generate(`Describe the following pdf file. ${pdf5}.`);
    if description is string {
        test:assertFail("Expected an error for invalid URL in the file document.");
    }
    test:assertEquals(description.message(), "Must be a valid URL.");

    description = mistralProvider->generate(`Describe the following pdf file. ${pdf2}.`);
    if description is string {
        test:assertFail("Expected an error for unsupported content type in the file document.");
    }
    test:assertEquals(description.message(), "Currently, only URL based file documents are supported.");

    description = mistralProvider->generate(`Describe the following pdf file. ${pdf}.`);
    if description is string {
        test:assertFail("Expected an error for invalid URL in the file document.");
    }
    test:assertEquals(description.message(), "Currently, only URL based file documents are supported.");
}

@test:Config
function testGenerateMethodWithRecordArrayReturnType() returns error? {
    int maxScore = 10;
    Review r = check reviewStr.fromJsonStringWithType(Review);

    ReviewArray|error result = mistralProvider->generate(`Please rate this blogs out of ${maxScore}.
        [{Title: ${blog1.title}, Content: ${blog1.content}}, {Title: ${blog2.title}, Content: ${blog2.content}}]`);
    test:assertEquals(result, [r, r]);
}

@test:Config
function testGenerateMethodWithInvalidBasicType() returns ai:Error? {
    boolean|error rating = mistralProvider->generate(`What is ${1} + ${1}?`);
    test:assertTrue(rating is error);
    test:assertTrue((<error>rating).message().includes(ERROR_MESSAGE));
}

type ProductName record {|
    string name;
|};

@test:Config
function testGenerateMethodWithInvalidRecordType() returns ai:Error? {
    ProductName[]|map<string>|error rating = trap mistralProvider->generate(
                `Tell me name and the age of the top 10 world class cricketers`);
    string msg = (<error>rating).message();
    test:assertTrue(rating is error);
    test:assertTrue(msg.includes(RUNTIME_SCHEMA_NOT_SUPPORTED_ERROR_MESSAGE),
            string `expected error message to contain: ${RUNTIME_SCHEMA_NOT_SUPPORTED_ERROR_MESSAGE}, but found ${msg}`);
}

type ProductNameArray ProductName[];

@test:Config
function testGenerateMethodWithInvalidRecordArrayType2() returns ai:Error? {
    ProductNameArray|error rating = mistralProvider->generate(
                `Tell me name and the age of the top 10 world class cricketers`);
    test:assertTrue(rating is error);
    test:assertTrue((<error>rating).message().includes(ERROR_MESSAGE));
}


type Cricketers record {|
    string name;
|};

type Cricketers1 record {|
    string name;
|};

type Cricketers2 record {|
    string name;
|};

type Cricketers3 record {|
    string name;
|};

type Cricketers4 record {|
    string name;
|};

type Cricketers5 record {|
    string name;
|};

type Cricketers6 record {|
    string name;
|};

type Cricketers7 record {|
    string name;
|};

type Cricketers8 record {|
    string name;
|};

@test:Config
function testGenerateMethodWithStringUnionNull() returns error? {
    string? result = check mistralProvider->generate(`Give me a random joke`);
    test:assertTrue(result is string);
}

@test:Config
function testGenerateMethodWithRecUnionBasicType() returns error? {
    Cricketers|string result = check mistralProvider->generate(`Give me a random joke about cricketers`);
    test:assertTrue(result is string);
}

@test:Config
function testGenerateMethodWithRecUnionNull() returns error? {
    Cricketers1? result = check mistralProvider->generate(`Name a random world class cricketer in India`);
    test:assertTrue(result is Cricketers1);
}

@test:Config
function testGenerateMethodWithArrayOnly() returns error? {
    Cricketers2[] result = check mistralProvider->generate(`Name 10 world class cricketers in India`);
    test:assertTrue(result is Cricketers2[]);
}

@test:Config
function testGenerateMethodWithArrayUnionBasicType() returns error? {
    Cricketers3[]|string result = check mistralProvider->generate(`Name 10 world class cricketers as string`);
    test:assertTrue(result is Cricketers3[]);
}


@test:Config
function testGenerateMethodWithArrayUnionNull() returns error? {
    Cricketers4[]? result = check mistralProvider->generate(`Name 10 world class cricketers`);
    test:assertTrue(result is Cricketers4[]);
}

@test:Config
function testGenerateMethodWithArrayUnionRecord() returns ai:Error? {
    Cricketers5[]|Cricketers6|error result = mistralProvider->generate(`Name top 10 world class cricketers`);
    test:assertTrue(result is Cricketers5[]);
}

@test:Config
function testGenerateMethodWithArrayUnionRecord2() returns ai:Error? {
   Cricketers7[]|Cricketers8|error result = mistralProvider->generate(`Name a random world class cricketer`);
    test:assertTrue(result is Cricketers8);
}
