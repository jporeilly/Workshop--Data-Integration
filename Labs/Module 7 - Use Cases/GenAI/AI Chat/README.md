## AI Chat Samples

## Overview

This directory contains various samples of using AI Chat Step plugin with OpenAI and Azure OpenAI.
It also has some use-cases that can be useful in understanding and using this step plugin.

## Important Information

The samples consist of examples from two LLM models: **OpenAI** and **Azure OpenAI**.

**OpenAI**

- OpenAI is a public LLM chat model. The demo uses the public version of the OpenAI.
- The OpenAI samples will run and generate chat responses without any changes to the configuration.
- The OpenAI samples are based on a default LLM model (`gpt-3.5-turbo`) with a default API key (`demo`) provided as part of the LangChain4j framework.
- The default configurations have limited functionality and are only for the purpose of test demos.
- There are usage and rate limits when using the above configuration. Please use them accordingly.
- Using the default configuration in **production** environment is strongly **NOT** recommended. Please use your own API key and configuration from OpenAI API Settings.

**Azure OpenAI**

- Azure OpenAI is a private LLM chat model. The demo uses a private azure settings.
- The Azure OpenAI samples will not run and generate chat responses without providing your own Azure OpenAI deployment Settings.
- Two Azure OpenAI Studio deployments are needed in this plugin: 1. For the Model Deployment and 2. For the Embedding Model Deployment.


## Use Cases

Below is a list of sample use-cases provided as part of the `samples/` folder.

| Use Case Name          | Use Case Description                                                                                                    | File                                                  |
|------------------------|-------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------|
| **Log Analysis**       | Analyze PDI logs to find errors in the log and use LLM to generate a response.                                          | AiChat Step Plugin - Usecase - Log Analysis.ktr       |
| **Sentiment Analysis** | Tweet Sentiment analysis on a list of downloaded tweets. Use LLM to categorize tweets as Positive, Negative or Neutral. | AiChat Step Plugin - Usecase - Sentiment Analysis.ktr |
| **SQL Analyzer**       | Analyze SQL files containing reporting tables to find the source table, target table and joining conditions.            | AiChat Step Plugin - Usecase - SQL Analyzer.ktr       |