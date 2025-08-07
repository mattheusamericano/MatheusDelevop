# MatheusDelevop
## salvando um novo 

2. Criação do Integration Runtime (IR)
A seguir, são apresentados os passos para criação de um Integration Runtime do tipo Azure:

Passo 1: Acesse a seção 'Integration runtimes' no menu lateral esquerdo e clique em '+ New'.

Passo 2: Selecione o tipo 'Azure, Self-Hosted'.

Passo 3: Escolha 'Azure' como ambiente de rede para atividades de fluxo de dados, movimentação e execução de pipelines.

Passo 4: Defina o nome do runtime e deixe a região como 'Auto Resolve'.

Passo 5: Configure a rede virtual (se necessário), ativando a opção de 'Interactive authoring'.

Passo 6: Ajuste os parâmetros de performance, como o número de nós e tempo de vida do runtime.

3. Configuração dos Linked Services
Após o IR estar configurado, você pode criar os Linked Services. Os exemplos a seguir ilustram a criação de três tipos diferentes:

Exemplo 1: Azure Key Vault: configure o nome, método de autenticação e subscrição.

Exemplo 2: Azure Blob Storage: defina o nome do serviço, selecione o runtime, identidade gerenciada e conta de armazenamento.

Exemplo 3: Azure SQL Database: informe nome, versão, runtime, servidor e nome do banco de dados.

4. Publicação das Alterações
Após a criação dos Linked Services, clique em 'Publish' para aplicar as alterações no ambiente ativo do Data Factory.

 
