# MatheusDelevop
## salvando um novo titulo


Documento Informativo – Configuração de Nodepools em Clusters AKS

Data: 04/08/2025
Responsável: [Nome do responsável ou equipe, se desejar incluir]

1. Objetivo

Informar sobre os padrões de configuração adotados para os nodepools em clusters AKS, utilizados nos ambientes corporativos.

2. Estrutura dos Nodepools

Foram definidos os seguintes critérios de segmentação:
	•	Criação de nodepools específicos por sistema, com segregação entre backend e frontend:
	•	backend = app+sigla-do-projeto
	•	frontend = website+sigla-do-projeto
	•	Criação de nodepool específico para troubleshooting e instalação de addons, com o nome padrão:
	•	infra
	•	Possibilidade de utilização de IP privado ou IP público para exposição do frontend, conforme a necessidade de cada solução.




zones = (
  each.value.sku_name == "Premium"
  ? (
      length(try(each.value.apim_availabilityzone, [])) > 0
      ? each.value.apim_availabilityzone
      : ["1", "2"]
    )
  : null
)





zones = (
    # Se apim_availabilityzone foi definido, usa ele
    try(each.value.apim_availabilityzone, null) != null ? each.value.apim_availabilityzone :
    # Se é Premium, usa ["1", "2"] por padrão
    each.value.sku_name == "Premium" ? ["1", "2"] :
    # Para outros tiers, usa apenas ["1"]
    ["1"]
  )

 
