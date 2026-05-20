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

import ballerina/http;
import ballerinax/mistral;

# Configurations for controlling the behaviours when communicating with a remote HTTP endpoint.
@display {label: "Connection Configuration"}
public type ConnectionConfig record {|

    # The HTTP version understood by the client
    @display {label: "HTTP Version"}
    http:HttpVersion httpVersion = http:HTTP_2_0;

    # Configurations related to HTTP/1.x protocol
    @display {label: "HTTP1 Settings"}
    http:ClientHttp1Settings http1Settings?;

    # Configurations related to HTTP/2 protocol
    @display {label: "HTTP2 Settings"}
    http:ClientHttp2Settings http2Settings?;

    # The maximum time to wait (in seconds) for a response before closing the connection
    @display {label: "Timeout"}
    decimal timeout = 60;

    # The choice of setting `forwarded`/`x-forwarded` header
    @display {label: "Forwarded"}
    string forwarded = "disable";

    # Configurations associated with request pooling
    @display {label: "Pool Configuration"}
    http:PoolConfiguration poolConfig?;

    # HTTP caching related configurations
    @display {label: "Cache Configuration"}
    http:CacheConfig cache?;

    # Specifies the way of handling compression (`accept-encoding`) header
    @display {label: "Compression"}
    http:Compression compression = http:COMPRESSION_AUTO;

    # Configurations associated with the behaviour of the Circuit Breaker
    @display {label: "Circuit Breaker Configuration"}
    http:CircuitBreakerConfig circuitBreaker?;

    # Configurations associated with retrying
    @display {label: "Retry Configuration"}
    http:RetryConfig retryConfig?;

    # Configurations associated with inbound response size limits
    @display {label: "Response Limit Configuration"}
    http:ResponseLimitConfigs responseLimits?;

    # SSL/TLS-related options
    @display {label: "Secure Socket Configuration"}
    http:ClientSecureSocket secureSocket?;

    # Proxy server related options
    @display {label: "Proxy Configuration"}
    http:ProxyConfig proxy?;

    # Enables the inbound payload validation functionality which provided by the constraint package. Enabled by default
    @display {label: "Payload Validation"}
    boolean validation = true;
|};

# Models types for Mistral AI
@display {label: "Mistral AI Model Names"}
public enum MISTRAL_AI_MODEL_NAMES {
    MISTRAL_SMALL_LATEST = "mistral-small-latest",
    MISTRAL_MEDIUM_LATEST = "mistral-medium-latest",
    MISTRAL_LARGE_LATEST = "mistral-large-latest",
    DEVSTRAL_SMALL_LATEST = "devstral-small-latest",
    PIXTRAL_LARGE_LATEST = "pixtral-large-latest",
    MINISTRAL_3B_LATEST = "ministral-3b-latest",
    MINISTRAL_8B_LATEST = "ministral-8b-latest",
    MISTRAL_SABA_LATEST = "mistral-saba-latest",
    CODESTRAL_LATEST = "codestral-latest",
    MISTRAL_SMALL_2402 = "mistral-small-2402",
    MISTRAL_SMALL_2409 = "mistral-small-2409",
    MISTRAL_SMALL_2501 = "mistral-small-2501",
    MISTRAL_SMALL_2503 = "mistral-small-2503",
    MINISTRAL_3B_2410 = "ministral-3b-2410",
    MINISTRAL_8B_2410 = "ministral-8b-2410",
    MISTRAL_MEDIUM_2312 = "mistral-medium-2312",
    MISTRAL_MEDIUM_2505 = "mistral-medium-2505",
    MISTRAL_LARGE_2402 = "mistral-large-2402",
    MISTRAL_LARGE_2407 = "mistral-large-2407",
    MISTRAL_LARGE_2411 = "mistral-large-2411",
    MISTRAL_SABA_2502 = "mistral-saba-2502",
    CODESTRAL_2405 = "codestral-2405",
    CODESTRAL_2501 = "codestral-2501",
    CODESTRAL_MAMBA_2407 = "codestral-mamba-2407",
    DEVSTRAL_SMALL_2505 = "devstral-small-2505",
    OPEN_MISTRAL_7B = "open-mistral-7b",
    OPEN_MISTRAL_NEMO = "open-mistral-nemo",
    OPEN_MIXTRAL_8X7B = "open-mixtral-8x7b",
    OPEN_MIXTRAL_8X22B = "open-mixtral-8x22b",
    PIXTRAL_LARGE_2411 = "pixtral-large-2411",
    PIXTRAL_12B_2409 = "pixtral-12b-2409",
    OPEN_CODESTRAL_MAMBA = "open-codestral-mamba"
}

# Embedding model types for Mistral AI
@display {label: "Mistral AI Embedding Model Names"}
public enum MISTRAL_AI_EMBEDDING_MODEL_NAMES {
    MISTRAL_EMBED = "mistral-embed",
    CODESTRAL_EMBED = "codestral-embed"
}

# Mistral message record.
type MistralMessages mistral:AssistantMessage|mistral:SystemMessage|mistral:UserMessage|mistral:ToolMessage;
