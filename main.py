import csv
import os
import json
import requests
import concurrent.futures


class CNESExtractor:
    def __init__(self, csv_file_path):
        self.csv_file_path = csv_file_path
        self.headers = {'Referer': 'https://cnes.datasus.gov.br/pages/estabelecimentos/consulta.jsp'}

    def executar(self, dict_document):
        try:
            self.download_pdf(dict_document['cnes'])
        except Exception as e:
            dict_document.update({"erro": True, "args":e.args})
        self.salvar_json(dict_document)

    def salvar_json(self, _json):
        with open("dados_python.json", 'a') as f:  
            json.dump(_json, f)
            f.write('\n') 
    
    def consulta_concorrente(self, document):
        with concurrent.futures.ThreadPoolExecutor(max_workers=100) as executor:
           executor.map(self.executar, document)

    def read_csv(self):
        with open(self.csv_file_path, 'r') as arquivo_csv:
            leitor_csv = csv.reader(arquivo_csv)
            linhas_csv = list(leitor_csv)
        return linhas_csv[1:]

    def get_estado_id(self, estado_nome):
        get_estados = requests.get('https://cnes.datasus.gov.br/services/estados', headers=self.headers)
        for key, estado_id in get_estados.json().items():
            if estado_id == estado_nome:
                return key

    def get_cidade_id(self, estado_id, cidade_nome):
        params = {'estado': estado_id}
        get_cidades = requests.get('https://cnes.datasus.gov.br/services/municipios', params=params, headers=self.headers)
        for key, cidade_id in get_cidades.json().items():
            if cidade_id == cidade_nome.upper():
                return key

    def get_estabelecimentos(self, municipio_id):
        params = {'municipio': municipio_id}
        return requests.get('https://cnes.datasus.gov.br/services/estabelecimentos', params=params, headers=self.headers).json()

    def download_pdf(self, estabelecimento_id):
        with open('payload_ficha.json', 'r') as arquivo_json:
            json_data = json.load(arquivo_json)

        response = requests.post(
            f'https://cnes.datasus.gov.br/services/estabelecimentos/relatorios/ficha-completa/{estabelecimento_id}',
            headers=self.headers,
            json=json_data,
        )
 
        if not os.path.exists("pdf_request"):
            os.makedirs("pdf_request")

        nome_arquivo_pdf = f"pdf_request/{estabelecimento_id}.pdf"
        with open(nome_arquivo_pdf, 'wb') as f:
            f.write(response.content)


if __name__ == "__main__":
    extractor = CNESExtractor('./LOCALIDADES.CSV')
    linhas_csv = extractor.read_csv()
    for value in linhas_csv:
        uf, cidade = value[0], value[1]

        estado_id = extractor.get_estado_id(uf)
        cidade_id = extractor.get_cidade_id(estado_id, cidade)
        estabelecimentos = extractor.get_estabelecimentos(cidade_id)
        extractor.consulta_concorrente(estabelecimentos)
