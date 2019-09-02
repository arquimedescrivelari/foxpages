# Fox Pages Server 3.5

## 这是什么玩意儿?

Fox Pages Server (FPS) 是一个针对 Visual FoxPro 的多线程 HTTP, HTTPS, 和 FastCGI 服务。

利用 Fox Pages Server 你可以通过使用 Visual FoxPro 来开发、调试以及分发 WEB 内容和应用程序。

Fox Pages Server 并不能允许在 Internet 上运行 Visual FoxPro 代码。所以，你还必须要知道和了解和 Internet 有关的语言和开发工具，例如：HTML,CSS,Javascript,JQuery,Dojo 等等。

Fox Pages Server可以与boa平台结合使用。 这样，您可以在不了解Web开发语言的情况下创建Web应用程序。 Fox Pages Server与BOA通信。

## 前提条件
Microsoft Visual FoxPro 9.0

## 发布
Fox Pages Server 有两种模式的发布方式：开发模式和分发模式。

### 开发模式
在此模式下，服务默认工作在单线程方式，因此你可以使用 Visual FoxPro 来运行 FXP(编译后的PRG文件)。使用此模式时，需要在服务端安装有 Visual FoxPro。

### 分发模式
在此模式下，服务工作在多线程方式，这会带来极大的性能提升。使用此模式时，需要在服务端安装有 Visual FoxPro 运行库。

无论你使用哪种模式，所有的错误都会被记录在 LOGS 目录下的表中，这位你检测和跟踪错误提供了便利。

## 安装前需要注意的事项
不要尝试在同一计算机上同时安装开发模式和分发模式。如果你非要安装两种模式，你可以在分发模式中通过执行 install.bat 来进行安装。这样会自动注册并创建 Windows 服务。然后在开发模式下使用不同于分发模式的 IP 地址和端口。

### 安装开发模式
1) 定位到 Development 目录。
2) 运行 install.bat （如果在 win10 下安装，你需要以管理员权限来运行它）
3) 运行所需的协议程序，默认情况下，它是 SERVERS 目录下的 HTTP.FXP 文件。

Visual FoxPro 的调试器只能工作在开发模式下，因为当代码运行以多线程方式(dll)运行时，调试器没有办法显示任何的接口。你的任意的试图调试的操作都会产生错误或者使程序被冻结（暂时不知道确切含义，字面翻译，也许是挂起，也许是终止）。

### 安装分发模式
1) 定位到 Distribution 目录。
2) 运行 install.bat  （如果在 win10 下安装，你需要以管理员权限来运行它）

### 安全提示
不建议将 HTML 和 FXP 文件放置在同一目录下。如果你这样做，FXP 文件很容易通过浏览器就被下载了。

## 使用前的注意事项
Fox Pages 默认情况下针对 HTTP 协议使用 80 端口，所以，在开始使用前，你需要停止所有使用 80 端口的所有WEB服务(IIS,Apache等)，或者，在开发模式下，你通过更改 SERVERS 目录下的 HTTP.PRG 文件来更改所使用的端口，抑或在分发模式下，你通过 DATA 目录下 SERVERS.DBF 表的 PORT 字段进行更改。

其他协议（所使用端口）的更改遵循同样的过程。

## 设置 HTTP 和 HTTPS 服务

DATA 目录下的 FPS.DBC 数据库存储了服务的配置。
数据库中的表、字段的文档描述存贮在 FPS.HTML 文件。
数据库中各表的关系你通过查看 FPS.JPG 就可以看到。

### 服务器
服务器负责连接客户端(IE,Chrome,Firefox等)和服务端(NGinX等)。

每一个服务都运行在单独的线程上，并且可以根据 IP 地址在同一个端口进行监听。如果 IP 地址和端口存在冲突，将使用第一个第一个成功配置的服务接收连接。

配置服务仅需要你针对 SERVERS.DBF 表进行增加、编辑或删除记录就可以完成。

每个协议都有自己默认的特定端口：

- HTTP 必须配置为 80 端口。
- HTTPS 必须配置为 443 端口。

FastCGI 通常用于服务间的通讯，它不存在默认端口。

### 站点
站点建立就是在文件夹(例如：c:\sites\example) 和 HOSTNAME(例如：www.example.com)之间建立关联，并配置你的主页(例如：index.fxp, index. php, index.html等)。

配置站点你可以通过增加、编辑或者删除 SITES.DBF 表中的记录进行。

如果 HOSTNAME 字段值为 "*"，那么所有的 HOSTNAMES 都将和同一目录建立关联。

在 SITES.DBF 中，我们可以通过 REDIRECT 字段中填入完整的地址来配置重定向。当你需要这么做的时候，它是非常有用的，例如，你可以将一个不安全的HTTP连接重定向到一个安全的HTTPS连接。这里有一个例子：你可以在字段中填入"www.example.com"，就可以将一个不安全的(HTTP://www.example.com)的连接重定向到一个安全的连接(HTTPS://www.example.com)。

### 网关
网关通常用于向其他的开发工具发送请求。我仅仅测试了PHP，当然它和其他支持 FastCGI 的开发工具都保持了兼容。

配置网关是通过增加、编辑或者删除 GATEWAYS.DBF 表中的记录来进行的。

它仅仅支持 FastCGI 协议。

网关的工作方式和站点类似，也是在 HOSTNAME(例如：www.example.com) 和 目录(例如：c:\sites\example)之间建立关联。不同的地方在于，你必须在请求的 URI 中包含 URI 文件(例如：".php")以便它可以被发送至网关。

基于这些条件，Fox Pages Server 转换 HTTP 请求为一个 FastCGI 请求，并将其发送到所配置的服务商。FastCGI 的返回信息也被转换为一个 HTTP 返回信息并发送给客户端。

不符合条件的请求将由 HTTP 服务来进行处理，因此你需要为站点的每一个网关都要进行配置。

### 安全
网站中所包含的所有文件未必都需要访问，例如数据库，数据表，程序这些。

Fox Pages Server 的访问控制允许站点目录的授权访问或者完全阻止访问。

访问控制是通过增加、编辑或者删除REALMS.DBF, USERS.DBF, 和 REALMUSER.DBF 中的记录来完成的。

REALM.DBF 负责设置针对站点目录的访问控制。

USERS.DBF 定义了可以访问文件夹的用户。

REALMUSER.DBF 列出了拥有文件夹的用户。

### CORS（跨源资源共享）
它是一种浏览器机制，可防止原始（域）未经授权访问不同来源（另一个域）中的资源。

通过在CORS.DBF表中添加，修改或删除记录来配置授权。

在SITE字段中输入将授予授权的站点。 该字段与SITES.DBF表相关。

在ORIGIN字段中输入原点（授权域），如果填充“*”，则允许任何原点。

在URI字段中输入资源，如果填充“*”，则允许任何拒绝。

GET，POST，PUT，DELETE，HEAD和OPTIONS字段确定允许哪些方法。

必须使用允许的HTTP标头填充HEADER字段。 它们应该用逗号分隔，然后用空格分隔。

## 设置 FastCGI 服务

Fox Pages Server 可以配置为其他WEB服务商使用 FastCGI 协议。

NGINX 目录下的 nginx.conf 是针对 NGinX 服务的一个配置模板。拷贝这个文件到已安装 NGinx 的 CONF 文件夹下，并使用带完整路径的站点文件目录作为 ROOT 参数即可。

如需配置 Fox Pages Server 使用 FastCGI 协议，你需要填充 SERVERS.DBF 表的 TYPE 字段内容为 "FCGI"。

由于处理请求所需的所有信息都必须由 web 服务器提供, 因此无需配置站点、网关或安全。

## 第一次访问
在服务启动后，你可以通过在浏览器中键入配置好的地址来完成第一次访问(例如： http://localhost, https://localhost).

## Demo 站点
有两个账号可以进入演示站点，一个是用于客户端，一个用于代理。

客户账号的使用方法：用户名为 cliente@teste.com.br ，密码为 123456

代理账号用于客户订单，用户名为 representante@teste.com.br ，密码为 123456.

### 动态页面
动态页面使用服务器端编程语言开发网站或 Internet 应用程序。

Fox Server Pages 使开发这些网页成为可能, 利用静态页面的资源 (如 HTML, CSS, Javascript) 与Visual FoxPro 编程特性 (例如控制语句, 数据库)。

在 Fox Pages Server 中 HTML 页被转换为 PRG 程序文件并编译为 FXP 文件, 因此页面处理速度非常快, 并且没有使用其他解释器的限制。

在编译过程中，只处理`<FPS>`和`</FPS>`标记之间的代码，其余部分将作为静态内容发送。

静态内容的一个例子。
在编译过程中, 只有在`<FPS>`和`</FPS>`之间的代码被处理, 其余部分将作为静态内容发送。

静态内容的示例.
```
<HTML>
Hello World
</HTML>
```
结果：

Hello World  

这个例子缺少`<FPS>`和`</FPS>`标记，所以也被作为静态页面输出。
```
<HTML>
for nCounter = 1 to 3
    Hello World
next
</HTML>
```
结果：

for lnCounter = 1 to 3  
    Hello World  
next  

一个使用标记的例子，它们负责发送静态文本和表达式。
```
<HTML>
    <FPS>
       cWorld = "World"
       for nCounter = 1 to 3
          <t>Hello </t><e>cWorld</e><br>
       next
    </FPS>
</HTML>
```
结果：

Hello World  
Hello World  
Hello World  

使用其他 HTML 标记组合编程的示例。每行都以 HTML 标记开始, 或由标记发送。
```
<HTML>
    <FPS>
       <b>Begin</b><br><br>

       cWorld = "World"
       for nCounter = 1 to 3
          <b><t>Hello </t><e>cWorld</e></b><br>
       next

       <br>
       <t>End</t>
    </FPS>
</HTML>
```
结果：

Begin  

Hello World  
Hello World  
Hello World  

End  

## RESTfull Applications
REST (Representational State Transfer)
是一种架构风格，它主张Web应用程序应该按照最初的意图使用HTTP，其中GET，PUT，POST和DELETE请求应分别用于查询，更改，创建和删除。

只要Accept标头是“application/json”或“application/xml”，Fox Pages Server就会将请求处理为REST。

使用代理帐户登录时，可以在演示网站上的应用程序中找到更多详细信息。

### Boa Platform

使用Fox Pages Server，您可以构建REST API以满足BOA平台的请求。 您可以在Visual Foxpro中创建一个完整的Web应用程序。 Fox Server Pages将响应BOA发送的请求。 Fox Server Pages和BOA之间发送的数据很容易理解JSON字符串。

设置Visual Fox页面后，您可以测试此组合的功能。 在https://www.BOA-platform.com上或通过以下直接链接启动演示：http：//demo.boa-platform.com。 出现登录屏幕时，您可以使用以下内容：

用户：en

密码：en01

API服务器的URL：http://localhost/boa。 这是您当地的Fox Pages Server。

有关示例源代码，请参阅demo / boa文件夹。

## 与2.0版本不兼容
对于FastCGI协议支持，Request和Response对象属性的处理已更改。

在带有连接字符的2.0版本的头文件中（例如Accept-Encoding）删除了连接字符（例如AcceptEnconding）。 在3.0版中，这些连接字符被改为下划线（例如Accept_Encoding）。

## 协议许可
Fox Pages Server 是一个自由和开源的软件。许可协议位于 LICENSE 文件。

用于连接的组件来自于 Catalyst Development Corporation (www.sockettools.com) 的 Socketwrench。

这个组件有自由和商业两个版本。自由版本不支持安全连接 (SSL/TLS).

Fox Pages Server 的开发模式使用 SocketWrench 的自由版本。如果你需要在开发环境中使用安全连接，那么这是一个限制。

如果你需要商业版的 SocketWrench 那么你需要购买一份许可。Fox Pages Server 并不包含商业许可。

SocketWrench 的自由或商业版本的配置，位于 CORE 目录下的 FOXPAGES.H 文件，就像下面你看到的这样：

//SOCKETWRENCH  
#DEFINE USEFREEVERSION  
#DEFINE CSWSOCK_CONTROL		"SocketTools.SocketWrench.6"  

//SocketWrench 8  
//#DEFINE CSWSOCK_CONTROL		"SocketTools.SocketWrench.8"  
//#DEFINE CSWSOCK_LICENSE_KEY	"INSERT YOUR RUNTIME LICENSE HERE"  

//SocketWrench 9  
//#DEFINE CSWSOCK_CONTROL		"SocketTools.SocketWrench.9"  
//#DEFINE CSWSOCK_LICENSE_KEY	"INSERT YOUR RUNTIME LICENSE HERE"  

如果你更改了设置，那么你需要重新编译你的项目。

##什么是新的？

### v3.5  - 发布2019.09.02

-  BOA plataform支持
- 跨源资源共享（CORS）支持
- 使用安全连接更正数据读取错误
- 一些重命名的类和财产
- 安全更新。 SocketWrench控件已更新至9.5版（发行说明，请访问https://sockettools.com/release-notes/）

### v3.1  - 发布2018.06.26

- 安全更新。 SocketWrench控件已更新至9.3版（发行说明，请访问https://sockettools.com/release-notes/）

## 鸣谢

多线程处理 - VFP2C32T.FLL - Christian Ehlscheid  
压缩 - VFPCompression - Craig Boyd  
加密 - VFPEncryption - Craig Boyd  
JSON 解析器 - Modified library version - Craig Boyd  
Sockets - Socketwrench - Catalyst Development  

## 捐赠
如果你觉得这个项目对你是非常有用的，那么你可以考虑捐赠我们。

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=XEXS5TAWJG7YL)