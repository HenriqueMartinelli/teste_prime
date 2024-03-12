*** Settings ***
Library    OperatingSystem
Library    String
Library    Collections
Library    RequestsLibrary
Library    JSONLibrary
Library    DateTime


*** Variables ***
${CSV_FILE_PATH}    ./LOCALIDADES.CSV
${HEADERS}    {'Referer': 'https://cnes.datasus.gov.br/pages/estabelecimentos/consulta.jsp'}
${JSON_FILE_PATH}  ./payload_ficha.json
${NOME_ARQUIVO_JSON}   dados.json


*** Test Cases ***
Extrair Dados CNES
    ${linhas_csv}=    Ler CSV    ${CSV_FILE_PATH}
    FOR    ${valor}    IN    @{linhas_csv}
        @{valor}=    Split String    ${valor}    ,
        ${uf}=    Set Variable    ${valor}[0]
        ${cidade}=    Set Variable    ${valor}[1]
        ${estado_id}=    Obter ID Estado    ${uf}

        ${cidade_id}=    Obter ID Cidade    ${estado_id}    ${cidade}
        ${estabelecimentos}=    Obter Estabelecimentos    ${cidade_id}
        Consulta Concorrente    ${estabelecimentos}
    END



*** Keywords ***
Ler CSV
    [Arguments]    ${caminho_csv}
    ${arquivo_csv}=    Get File    ${caminho_csv}
    @{linhas_csv}=    Split To Lines    ${arquivo_csv}
    RETURN    @{linhas_csv}[1:]

Obter ID Estado
    [Arguments]    ${estado_nome}
    ${headers}=    Create Dictionary    Referer    https://cnes.datasus.gov.br/pages/estabelecimentos/consulta.jsp
    ${response}=    GET    https://cnes.datasus.gov.br/services/estados    headers=${HEADERS}
    ${estados}=    Evaluate    json.loads($response.content)    json

    FOR    ${key}    IN    @{estados.keys()}
        ${estado_id}=    Set Variable    ${estados["${key}"]}

        IF    '${estado_id}' == '${estado_nome}'
            RETURN    ${key}
        END
    END
    
    
Obter ID Cidade
    [Arguments]    ${estado_id}    ${cidade_nome}
    ${params}=    Create Dictionary    estado=${estado_id}
    ${headers}=    Create Dictionary    Referer    https://cnes.datasus.gov.br/pages/estabelecimentos/consulta.jsp

    ${response}=    GET    https://cnes.datasus.gov.br/services/municipios    params=${params}    headers=${HEADERS}
    ${cidades}=    Evaluate    json.loads($response.content)    json

    FOR    ${key}    IN    @{cidades.keys()}
        ${cidade_id}=    Set Variable    ${cidades["${key}"]}

        IF    "${cidade_id}" == "${cidade_nome.upper()}"
            RETURN    ${key}
        END
    END


Obter Estabelecimentos
    [Arguments]    ${municipio_id}
    ${headers}=    Create Dictionary    Referer    https://cnes.datasus.gov.br/pages/estabelecimentos/consulta.jsp

    ${params}=    Create Dictionary    municipio=${municipio_id}
    Log To Console   ${params}
    ${response}=    GET    https://cnes.datasus.gov.br/services/estabelecimentos    params=${params}    headers=${HEADERS}
    ${estabelecimentos}=    Evaluate    json.loads($response.content)    json
    RETURN    ${estabelecimentos}


*** Keywords ***
Salvar Consulta em Arquivo JSON
    [Arguments]    ${consulta}
    ${json_string}=    Evaluate    json.dumps($consulta)
    Append To File    ${NOME_ARQUIVO_JSON}    ${json_string}    encoding=UTF-8
    Append To File    ${NOME_ARQUIVO_JSON}    \n    encoding=UTF-8


Consulta Concorrente
    [Arguments]    ${estabelecimentos}
    FOR    ${estabelecimento}    IN    @{estabelecimentos}
        ${pdf_id}=    Set Variable    ${estabelecimento['cnes']}
        ${error_occurred}=    Run Keyword And Return Status    Download PDF    ${estabelecimento['cnes']}
        Run Keyword If    ${error_occurred}    Set To Dictionary    ${estabelecimento}    error=${True}
        Salvar Consulta em Arquivo JSON    ${estabelecimento}
    END
    

Download PDF
    [Arguments]    ${estabelecimento_id}
    ${json_data}=    Get File    ${JSON_FILE_PATH}

    ${parsed_json}=    Evaluate    json.loads($json_data)    json

    ${headers}=    Create Dictionary    Referer    https://cnes.datasus.gov.br/pages/estabelecimentos/consulta.jsp
    ${response}=    POST    https://cnes.datasus.gov.br/services/estabelecimentos/relatorios/ficha-completa/${estabelecimento_id}    headers=${HEADERS}    json=${parsed_json}
    ${nome_arquivo_pdf}=    Set Variable    pdf_request/${estabelecimento_id}.pdf
    
    ${dir_path}=    Join Path    ${CURDIR}    pdf_request
    ${dir_exists}=    Run Keyword And Return Status    Directory Should Exist    ${dir_path}
    Run Keyword If    "${dir_exists}" == "False"    Create Directory    ${dir_path}
    
    Create Binary File    ${nome_arquivo_pdf}    ${response.content}