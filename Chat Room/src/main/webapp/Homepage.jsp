
<%@ page language="java" contentType="text/html; charset=ISO-8859-1"
    pageEncoding="ISO-8859-1"%>
<%@ page import="java.io.*,java.util.*, java.time.*, java.text.*, java.util.Date, java.sql.*"%>
<%@ page import="javax.servlet.http.*,javax.servlet.*"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="ISO-8859-1">
<title>Home - Hydar</title>
<link rel="shorcut icon" href="favicon.ico"/>
</head>
<script type="text/javascript" src ="https://ajax.googleapis.com/ajax/libs/jquery/3.2.1/jquery.min.js"></script>

<body>
<body style = "background-color:rgb(51, 57, 63);"> 
<center>
<style type="text/css">
form{ display: inline-block; }
</style>

<div id="show">
</div>
<%
Class.forName("com.mysql.jdbc.Driver").newInstance();
Connection conn = DriverManager.getConnection("jdbc:mysql://localhost:3306/chatroom?autoReconnect=true&useSSL=false", "root", "hydar");
try{
	//CHECK IF BOARD IS SPECIFIED, and redirect if the user does not have perms.
	
	String getBoard = request.getParameter("board");
	int board = 1;
	if(getBoard != null){
		board = Integer.parseInt(getBoard);
	}
	
	Statement stmt1 = conn.createStatement();
	String checkBoardsStr="SELECT user.username, user.boards FROM user WHERE user.username = \"" + session.getAttribute("username").toString() + "\"";
	ResultSet result1 = stmt1.executeQuery(checkBoardsStr);
	String boardString = " " + board + ",";
	while(result1.next()){
		boardString = " " + result1.getString("user.boards") + ",";
	}
	
	if(!boardString.contains(" " + board + ",")){
		board = 1;
	}
	
	//CHECK IF AUTO REFRESH IS ON
	
	String autoRefresh = request.getParameter("autoOn");
	if(autoRefresh == null){
		autoRefresh = "autoOn";
	}
	
	//CHECK IF USER IS LOGGED IN
	
	if(session.getAttribute("username").toString().equals("null")){
		throw new Exception();
	}
	
	out.print("</center>");
	
	//TOP BAR
	
	out.print("<h1 style = \"color:rgb(255,255,255); font-size:15px; font-family:arial; text-align:right;\"></style>");
	out.print("Hello " + session.getAttribute("username").toString() + "! | ");
	out.print("<style type=\"text/css\"> a{color:LightGrey; font-family:arial; text-align:right; font-size:15px}</style>");
	out.print("<a href=\"Profile.jsp\"> Profile</a>&nbsp;| ");
	out.print("<a href=\"Logout.jsp\"> Log out</a> &nbsp;&nbsp;");
	
	out.print("<style type=\"text/css\"> h1{color:rgb(255,255,255); text-align:left; font-size:15px}</style>");
	out.print("<img src=\"hydar.png\" alt=\"hydar\" width = \"25px\" height = \"40px\" align = \"center\">");
	out.print("&nbsp;&nbsp;&nbsp;Pick a board: ");
	out.print("<form method=\"get\" action=\"Homepage.jsp\">");
	out.print("<select name=\"board\">" );
	out.print("<option value = \"" + board + "\"> ---");
	out.print("<option value = \"1\"> everything else");
	out.print("<option value = \"2\"> sas4");
	out.print("<option value = \"3\"> skyblock");
	out.print("<input value=\"Go\"  type=\"submit\"></select></form>");
	
	out.print("</h1>");
	
	// GREY TEXT BAR
	
	out.print("<style> p{color:LightSlateGrey; font-family:arial; text-align:center; font-size:25px;}</style>");
	switch(board){
		case 1:
			out.print("<p>Viewing board: Everything else");
			break;
		case 2:
			out.print("<p>Viewing board: sas4");
			break;
		case 3:
			out.print("<p>Viewing board: skyblock");
			break;
		default:
			out.print("<p>Viewing board: Everything else");
			break;
	}
	out.print("&nbsp&nbsp|&nbsp&nbsp Auto update posts: ");
	out.print("<style> #two{color:LightSlateGrey; font-family:arial; text-align:center; font-size:25px;}</style>");
	if(autoRefresh.equals("autoOff")){
		out.print("<a id = \"two\" href=\"Homepage.jsp?autoOn=autoOn&board="+board+"\">");
		out.print("Off</a>");
	}else{
		out.print("<a id = \"two\" href=\"Homepage.jsp?autoOn=autoOff&board="+board+"\">");
		out.print("On</a>");
	}
	out.print("&nbsp&nbsp|&nbsp&nbsp");
	out.print("<a id = \"two\" href=\"javascript:void(0);\">");
	out.print("Instant update</a>");
	out.print("</p>");
	
	//out.print("<li>Search posts: ");
	//out.print("<form method=\"get\" action=\"Homepage.jsp\">");
	//out.print("<input type=\"text\" name=\"searchquery\" size=\"30\">");
	//out.print("<input value=\"Search\"  type=\"submit\"> </form> </li>");
	
	// SEARCH BAR
	
	out.print("<style> .nav{text-align:center; font-family:arial; list-style-type:none; margin:0; padding:0} .nav li{color:rgb(255,255,255); display:inline-block; font-size:20px; padding:30px}</style>");
	out.print("<ul class=\"nav\">");
	out.print("<li>Enter text to post:&nbsp");
	out.print("<form method=\"get\" action=\"SubmitPost.jsp\">");
	
	out.print("<input type=\"text\" name=\"input_text\" size=\"60\" style=\"background-color:rgb(71, 77, 83);color:white;border:none;padding:8px;\" autofocus=\"autofocus\" onfocus=\"this.select()\">");
	out.print("<input value=\"" + board + "\"  type=\"hidden\" name=\"board_num\">");
	out.print("<input value=\"  Post  \"  type=\"submit\" style=\"background-color:rgb(81, 87, 93);color:white;border:none;padding:8px; position:relative; left:3px\" > </form> </li>");
	out.print("</ul><br>");
	
	%>
		
	<!-- NEW MESSAGES  BAR -->
	
	<style> body{color:rgb(255,255,255); font-family:arial; text-align:left; font-size:15px;}</style>
		
	
	<div hidden id='bar' style='width: 100%; height: 20px; border-bottom: 2px solid #be4949; text-align: center'>
		<br>
		<span style='color:White; font-size: 12px; padding: 0 10px; position:relative; top:6px'>
			<b> - New Messages - </b>
		</span>
	</div>
	<div id="txtHint">Posts will be listed here...</div>
	<%

	// SHOW MESSAGES

	
	Statement stmt = conn.createStatement();
	String checkPostsStr="SELECT post.id, user.id, user.username, user.pfp, post.board, post.contents, post.created_date"
				+ " FROM user, posts, post"
				+ " WHERE posts.post = post.id AND user.id = posts.user AND post.board = " + board
				+ " ORDER BY post.id DESC";
	ResultSet result = stmt.executeQuery(checkPostsStr);
	//int topPostID = result.getInt("post.id");
	
	int count = 25; // <- DISPLAYED POSTS LIMIT XXXXXXXXXXXXXXXXXX
	
	out.print("<div id='msgs'>");
	out.print("<br>");
	while(result.next() && count > 0){
		//time
		float timePassed = ((float)(System.currentTimeMillis() - result.getLong("post.created_date")) / 3600000);
	
		out.print("<img src=\"" + result.getString("user.pfp") +"\" alt=\"hydar\" width = \"40px\" height = \"40px\" align = \"left\" hspace = \"10\" vspace = \"15\">");
		//other contents
		out.print("<style> body{color:LightGrey; font-family:arial; text-align:left; font-size:15px; display:block}</style>");
		out.print("<br><b><div id=\"msgUser\" style=\"display:inline\">"+ result.getString("user.username") + "</div></b> <p id=\"three\">");
		out.print("<style> #three{color:Grey; font-family:arial; text-align:left; font-size:15px; display:inline}</style>");
		if((timePassed * 60) < 1){
			out.print("&nbsp;(just now): ");
		}else if(timePassed < 1){
			out.print("&nbsp;(" + (int)(timePassed * 60) + " minutes ago): ");
		}else{
			out.print("&nbsp;(" + (int)(timePassed) + " hours ago): ");
		}
		
		//WHITELIST XxxxxxXXXXXXXXXXXXXXXXXXXX
		
		//html = html.replace(/</g, "&lt;").replace(/>/g, "&gt;");
		String fixedString = result.getString("post.contents").replaceAll("<", "&lt;");
		fixedString=fixedString.replaceAll("&lt;href", "<href").replaceAll("&lt;img", "<img");
		out.print("</p><br><div id=\"msgText\" style=\"display:inline\">" + fixedString +"</div><br clear = \"left\">");
	
		count-=1;
	}
	out.print("</div>");
	
	
	// SCRIPT TO AUTO UPDATE POSTS
	
	
	%>
		<script>
			document.addEventListener('click',()=>{document.getElementById("bar").setAttribute("hidden",true);});
			function refresh(){
				$.get(document.location.toString()).then(function (data) {
					var parser = new DOMParser();
					var doc = parser.parseFromString(data, "text/html");
					const hdar = document.createElement("div");
					hdar.setAttribute("id","msgs");
					hdar.innerHTML=doc.getElementById("msgs").innerHTML;var x=(hdar.children.length-document.getElementById("msgs").children.length)/8;
					
					if(document.querySelectorAll("[id='two']")[0].innerHTML.includes("Off")){
						document.getElementById("txtHint").innerHTML=""+(x>0?x:"No")+" new posts.<br>Posts will be listed here...";
						setTimeout(() => {
							document.getElementById("txtHint").innerHTML="Posts will be listed here...";
						},8000);
					}
					if(!(hdar.innerHTML==document.getElementById("msgs").innerHTML)){
						for(i in document.getElementById("msgs").querySelectorAll("[id = 'three']")){
							if(hdar.querySelectorAll("[id = 'three']").length>0){
								document.getElementById("msgs").querySelectorAll("[id = 'three']")[i].parentNode.replaceChild(hdar.querySelectorAll("[id = 'three']")[0],document.getElementById("msgs").querySelectorAll("[id = 'three']")[i]);
							}
						}hdar.innerHTML=doc.getElementById("msgs").innerHTML;
					if(!(hdar.innerHTML==document.getElementById("msgs").innerHTML)){
						document.getElementById("bar").removeAttribute("hidden");
						document.getElementById("msgs").parentNode.replaceChild(hdar,document.getElementById("msgs"));
						try{
							h=new Notification(document.getElementById("msgUser").innerHTML,{body:document.getElementById("msgText").innerHTML,icon:"https://cdn.discordapp.com/attachments/315971359102599168/921456500747173908/h.png"});
						}catch(e){
							
						}
					}
				}	
				}).fail(function () {document.querySelectorAll("[id='two']")[1].innerHTML="Loading...</a>"});
			}
			document.querySelectorAll("[id='two']")[1].addEventListener('click',refresh);
		</script>
	
	<%
	
	//AUTO RELOAD MESSAGES
	
	if(autoRefresh.equals("autoOn")){
		out.print("<script>");
		out.print("setInterval(refresh,1000);");
		out.print("</script>");
	}
	
	conn.close();
} catch (Exception e) {
	out.print("<style> body{color:rgb(255,255,255); font-family:arial; text-align:center; font-size:20px;}</style>");
	out.print("<center>");
	out.print("A known error has occurred.\n");
	out.print("<br><br>");
	out.print("<form method=\"get\" action=\"Logout.jsp\">");
	out.print("<td><input type=\"submit\" value=\"Back to login\"></td>");
	out.print("</form>");
	e.printStackTrace();
}
%>

</body>
</html>