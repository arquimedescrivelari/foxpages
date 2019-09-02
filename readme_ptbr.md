# Fox Pages Server 3.5

## O que é isto?

O Fox Pages Server (FPS) é um servidor HTTP, HTTPS e FastCGI multithread para Visual FoxPro.

Com o Fox Pages Server é possível desenvolver, depurar e distribuir conteúdo e aplicações para web utilizando o Visual FoxPro.

O Fox Pages Server não possibilita que código Visual FoxPro seja executado na internet. Por isso é necessário conhecimento das liguagens e ferramentas de desenvolvimento para internet que serão utilizadas, por exemplo: HTML, CSS, Javascript, JQuery, Dojo etc.

O Fox Pages Server pode ser usado com o boa-platform. Deste modo você pode criar aplicações Web sem mnenhum conhecimento de linguagens web. O Fox Pages se comunica com o serviço BOA.

## Requisitos
Microsoft Visual FoxPro 9.0

## Distribuição
O Fox Pages Server é distribuído em dois modos: modo de desenvolvimento e modo de distribuição.

### Modo de desenvolvimento
Neste modo, o servidor funciona por padrão em singlethread, para que seja possível a utilização do Visual FoxPro para o desenvolvimento de páginas FXP. O modo de desenvolvimento requer o Visual FoxPro instalado.

### Modo de distribuição
Neste modo, o servidor funciona em multithread, proporcionando um ganho extremo de processamento. O modo de distribuição requer o runtime do Visual FoxPro instalado.

Nos modos de desenvolvimento e distribuição qualquer erro é registrado em tabelas na pasta LOGS permitindo a detecção e rastreamento de erros.

## Antes de instalar
Não tente fazer o procedimento de instalação em modo de desenvolvimento e distribuição no mesmo computador. Se isto for necessário, execute o arquivo install.bat do modo de distribuição, pois ele registrará os componentes também criará o Serviço do Windows. Configure o modo de desenvolvimento para utilizar um IP ou porta diferente do modo de distribuição.

### Instalação em modo de desenvolvimento
1) Localize a pasta Development.
2) Execute o arquivo install.bat. (Para instalar no Windows 10 execute usando Prompt de comando como administrador)
3) Execute o programa do protocolo desejado, localizado na pastas SERVERS, HTTP.FXP é o padrão.

O debuguer do Visual FoxPro só funcionará no modo de desenvolvimento, pois é impossível a exibição de qualquer interface quando o código é executado em uma DLL multithread. Qualquer tentativa gerarm erros ou congelamento da thread.

### Instalação em modo de distribuição
1) Localize a pasta Distribuition.
2) Execute o arquivo install.bat. (Para instalar no Windows 10 execute usando Prompt de comando como administrador)

### Dica de segurança
Não é recomendado deixar os arquivos .HTML com os seus compilados .FXP na mesma pasta do servidor, eles podem ser baixados se a extensão for trocada no navegador.

## Antes de iniciar
O Fox Pages usa a porta 80 como padrão para HTTP, portanto antes de iniciar é necessário parar qualquer serviço que esteja usando a porta 80 (IIS, Apache, etc) ou alterar a porta usada no programa HTTP.PRG localizado na pasta SERVERS no o modo desenvolvimento, ou no campo PORT da tabela SERVERS.DBF localizado na pasta DATA no modo de distribuição.

Outros protocolos seguem o mesmo procedimento.

## Configuração de servidores HTTP e HTTPS

O banco de dados FPS.DBC localizado na pasta DATA armazena a configuração dos servidores.
A documentação das tabelas e seus respectivos campos podem ser encontrados no arquivo FPS.HTML.
O relacionamento entre as tabelas podem ser visualizados na imagem FPS.JPG.

### Servidores
O servidores são responsáveis pelas conexões dos clientes (IE, Chrome, Firefox, etc) e servidores (NGinX, etc).

Cada servidor é executado em uma thread separada e podem, dependendo da configuração do número IP, escutar uma mesma porta. Em caso de conflitos de números IP e portas o primeiro servidor configurado receberá as conexões.

Configure os servidores adicionando, modificando ou excluindo registros na tabela SERVERS.DBF.

Cada protocolo tem como padrão uma porta específica:

- HTTP deve ser configurado para porta 80.
- HTTPS deve ser configurado para porta 443.

FastCGI é normalmente utilizado na comunicação entre servidores, não há uma porta padrão.

### Sites
Os sites estabelecem uma relação entre um HOSTNAME (e.g. www.example.com) com a pasta onde os arquivos do site estão localizados (e.g. c:\sites\example), e configura a sua página inicial (e.g. index.fxp, index.php, index.html, etc).

Configure os sites adicionando, modificando ou excluindo registros na tabela SITES.DBF.

Caso o campo HOSTNAME seja preenchido com "*" todos os HOSTNAMES serão relacionados com uma mesma pasta.

Nesta mesma tabela configuramos redirecionamentos preenchendo o campo REDIRECT com o endereço completo do redirecionamento. Este recurso é muito util quando precisamos, por exemplo, redirecionar conexões não seguras (HTTP) para um servidor seguro (HTTPS), isto é feito por exemplo, preenchendo o campo REDIRECT do site www.example.com do servidor não seguro (HTTP) com "https://www.example.com", o endereço do site seguro (HTTPS).

### Gateways
Gateways são utilizados para enviar requisições para outras ferramentas de desenvolvimento. O PHP foi a única testada até o momento, entretando qualquer ferramenta que suporte FastCGI deve ser compatível.

Configure os gateways adicionando, modificando ou excluindo registros na tabela GATEWAYS.DBF.

O único protocolo suportado é FastCGI.

Gateways funcionam de uma forma semelhante aos Sites, estabelecendo uma relação entre um HOSTNAME (e.g. www.example.com) com a pasta onde os arquivos do site estão localizados (e.g. c:\sites\example). A diferença está no fato de que o conteúdo do campo URI (e.g. ".php") deve estar contido na URI da requisição para que a mesma seja enviada ao gateway.

Atendendo estes critérios, o Fox Pages Server transforma a requisição HTTP em uma requisição FastCGI e a enviada ao servidor configurado. A resposta FastCGI então é transformada em uma resposta HTTP e enviada ao cliente.

Requisições que não atendem os critérios, serão processadas pelo servidor HTTP, portanto para cada Gateway um Site deve ser configurado.

### Segurança
Nem todas a pastas e arquivos contidos em um site devem estar acessíveis. Bancos de dados, tabelas e programas são alguns exemplos.

O Fox Pages Server possui o sistema de controle de acesso que permite o acesso autorizado ou o bloqueio completo a pastas do site.

O controle de acesso é configurado adicionando, modificando ou excluindo registros das tabelas REALMS.DBF, USERS.DBF e REALMUSER.DBF

A tabela REALM.DBF define as configurações de acesso as pastas do site.

A tabela USERS.DBF define os usuários que terão acesso as pastas.

A table REALMUSER.DBF relaciona os usuários com as pastas.

### CORS (Cross-Origin Resource Sharing)
É um mecanismo dos navegadores que impedem que uma origem (domínio) acesse recursos em uma origem distinta (outro domínio) sem autorização.

Configure as autorizações adicionando, modificando ou excluindo registros na tabela CORS.DBF.

Informe o site que concederá autorização no campo SITE. Este campo é relacionado com a tabela SITES.DBF.

Informe a origem (domíno autorizado) no campo ORIGIN, caso seja preenchido com "*" qualquer origem será permitida.

Informe o recurso no campo URI, caso seja preenchido com "*" qualquer recuso será permitido.

Os campos GET, POST, PUT, DELETE, HEAD e OPTIONS determinam quais metódos são permitidos.

O campo HEADER deve ser preenchido com os headers HTTP permitidos. Devem ser delimitados com uma virgula seguida de um espaço.

## Configuração de servidores FastCGI

O Fox Pages Server pode ser configurado para ser utilizado através de outro servidores web utilizando o protocolo FastCGI.

O arquivo nginx.conf localizado na pasta NGINX é um modelo de configuração para o servidor NGinX. Copie este arquivo para a pasta CONF onde o NGinX está instalado e configure o parametro ROOT com o caminho completo da pasta dos arquivos do site.

Para configurar o Fox Pages Server para utilizar o protocolo FastCGI preencha o campo TYPE da tabela SERVERS.DBF com "FCGI".

Como todas as informações necessárias para o processamento da requisição devem ser fornecidas pelo servidor web, não há necessidade de configuração de sites, gateways ou segurança.

## Acessando a primeira vez
Após a inicialização do servidor utilize qualquer browser digitando no endereço do servidor configurado (e.g. http://localhost, https://localhost).

## Site de demonstração
Para entrar no site de demonstração existem duas contas, uma para o cliente e outra para o representante.

A conta do cliente da acesso a area do cliente. Para acessar utilize o email cliente@teste.com.br e a senha 123456.

A conta do representante inicia uma aplicação para cadastro de clientes e pedidos. Para acessar utilize o email representante@teste.com.br e a senha 123456.

## Como desenvolver usando o Fox Pages Server

### Páginas dinâmincas
Uma página dinâmica utiliza uma linguagem de programação server-side no desenvolvimento de um site ou aplicação para internet.

O Fox Pages Server torna possível o desenvolvimento destas páginas utilizando os recursos de desenvolvimentos de pagínas estáticas (e.g. HTML, CSS, Javascript) com os recursos de programação do Visual Fox Pro (e.g. liguagem de programação, banco de dados).

No Fox Pages Server uma pagina HTML é convertida em um arquivo de programa PRG e compilada para um arquivo compilado FXP, assim o processamento das paginas é extremamente rápido e não tem as limitações do uso de outro interpretador.

No processo de compilação apenas o código entre as tag `<FPS>` e `</FPS>` serão processados, o restante é enviado como conteúdo estático.

Um exemplo de conteúdo estático.
```
<HTML>
Olá mundo
</HTML>
```
Resultado:

Olá mundo  

Um exemplo de um programa como conteúdo estático por falta das tags `<FPS>` e `</FPS>`.
```
<HTML>
for nCounter = 1 to 3
   Olá mundo
next
</HTML>
```
Resultado:

for lnCounter = 1 to 3  
   Olá mundo  
next  

Um exemplo usando as tags `<t>` e `<e>`, elas são reponsáveis pelo envio de textos estáticos e expressões.
```
<HTML>
   <FPS>
      cMundo = "Mundo"
      for nCounter = 1 to 3
         <t>Olá </t><e>cMundo</e><br>
      next
   </FPS>
</HTML>
```
Resultado:

Olá mundo  
Olá mundo  
Olá mundo  

Um exemplo usando outras tags HTML combinadas a programação.
Toda linha iniciada com uma tag HTML ou pela tag `<t>` é enviada.
```
<HTML>
   <FPS>
      <b>Começo</b><br><br>

      cWorld = "Mundo"
      for nCounter = 1 to 3
         <b><t>Olá </t><e>cWorld</e></b><br>
      next

	<br>
	<t>Fim</t>
   </FPS>
</HTML>
```
Resultado:

Começo  

Ola mundo  
Ola mundo  
Ola mundo  

Fim  

## Aplicações RESTfull
REST (Representational State Transfer) é um estilo arquitetônico que defende que os aplicativos da Web devem usar o HTTP como era originalmente previsto, onde as requisições GET, PUT, POST e DELETE devem ser usados para consulta, alteração, criação e exclusão, respectivamente.

O Fox Pages Server processa uma requisição como REST sempre que o header Accept for "application/json" ou "application/xml".

Mais detalhes podem ser encontrados no aplicativo disponível no site de demonstração ao entrar com a conta do representante.

### BOA Plataform

Com Fox Pages Server você pode criar uma API REST para responder requisições da plataforma BOA. Você pode criar uma aplicação web completa usando o Visual Foxpro. O Fox Server Pages responderá as requisições que são enviadas pela plataforma BOA. Os dados que são trocados entre o Fox Pages Server e o BOA são strings JSON que são fáceis de entender.

Após a instalação do Fox Pages Server, você pode testar o poder desta combinação. Inicie o demo em https://www.boa-platform.com ou por este link direto: http://demo.boa-platform.com. Quando a tela de login aparecer, use o seguinte:

Usuário: en

Senha: en01

URL of API server: http://localhost/boa. Este é seu Fox Pages Server local.

Veja a pasta demo/boa para o código fonte deste demo.

## Incompatibilidade com a versão 2.0
Para o suporte ao protocolo FastCGI o processamento das propriedades dos objetos Request e Response foram alteradas.

Na versão 2.0 headers com hifen (e.g. Accept-Encoding) tinham o hifen removido (e.g. AcceptEnconding). Na versão 3.0 estes hifens são alterados para o sublinhado (e.g. Accept_Encoding).

## Licenciamento
O Fox Pages Server é um software livre e de código aberto. A licença esta localizada no arquivo LICENSE.

O componente usado para as conexões é o Socketwrench da empresa Catalyst Development Corporation (www.sockettools.com).

Este componente é distribuído nas versões gratuita e comercial. A versão gratuita não tem suporte para conexões seguras (SSL/TLS).

A versão de desenvolvimento do Fox Pages Server está configurada para utilizar a versão gratuita do SocketWrench. O que será uma limitação somente se o uso de conexões seguras no ambiente de desenvolvimento for necessário.

Para usar a versão comercial do SocketWrench é necessário comprar uma licença, pois o Fox Pages Server não inclui essa licença.

A configuração versão utilizada, gratuita ou comercial, ou a versão do SocketWrench, está localizada no arquivo FOXPAGES.H da pasta CORE, como segue abaixo:

//SOCKETWRENCH  
#DEFINE USEFREEVERSION  
#DEFINE CSWSOCK_CONTROL		"SocketTools.SocketWrench.6"  

//SocketWrench 8  
//#DEFINE CSWSOCK_CONTROL		"SocketTools.SocketWrench.8"  
//#DEFINE CSWSOCK_LICENSE_KEY	"INSERT YOUR RUNTIME LICENSE HERE"  

//SocketWrench 9  
//#DEFINE CSWSOCK_CONTROL		"SocketTools.SocketWrench.9"  
//#DEFINE CSWSOCK_LICENSE_KEY	"INSERT YOUR RUNTIME LICENSE HERE"  

É necessário recompilar o projeto após alterar estas configurações.

## Novidades?

### v3.5 - Lançamento 2019.09.02

- Suporte para plataform BOA
- Suporte para CORS (Cross-Origin Resource Sharing)
- Correção do erro de leitura de dados com conexões seguras
- Algumas classes e propriedade renomeadas
- Atualização de segurança. Controle SocketWrench atualizado para a versão 9.5 (Notas de versão em https://sockettools.com/release-notes/)

### v3.1 - Lançamento 2018.06.26

- Atualização de segurança. Controle SocketWrench atualizado para a versão 9.3 (Notas de versão em https://sockettools.com/release-notes/)

## Créditos

Multithreading - VFP2C32T.FLL - Christian Ehlscheid  
Compactação - VFPCompression - Craig Boyd  
Encriptação - VFPEncryption - Craig Boyd  
JSON Parser - Versão modificada da biblioteca - Craig Boyd  
Sockets - Socketwrench - Catalyst Development  

## Doação
Se este projeto é útil para você, cosidere uma doação.

[![paypal](https://www.paypalobjects.com/pt_BR/BR/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=PLGPFM9SF2X8G)
