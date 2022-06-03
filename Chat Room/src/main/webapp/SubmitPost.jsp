<%@ page language="java" contentType="text/html; charset=ISO-8859-1"
    pageEncoding="ISO-8859-1"%>
<%@ page import="java.io.*,java.util.*, java.time.*, java.text.*, java.util.Date, java.sql.*"%>
<%@ page import="javax.servlet.http.*,javax.servlet.*"%>
<!DOCTYPE html>
<html>
<head>
<meta charset="ISO-8859-1">
<title>Submitting Post... - Hydar</title>
<link rel="shorcut icon" href="favicon.ico"/>
</head>
<body>
<script type="text/javascript" src ="jquery-3.6.0.min.js"></script>
<style>
	body{
		background-image:url('hydarface.png');
		background-repeat:no-repeat;
		background-attachment:fixed;
		background-size:100% 150%;
		background-color:rgb(51, 57, 63);
		background-position: 0% 50%;
	}
</style>
<%


Class.forName("com.mysql.jdbc.Driver");
Connection conn = DriverManager.getConnection("jdbc:mysql://localhost:3306/chatroom?autoReconnect=true&useSSL=false", "root", "hydar");

try{
	
	//UPDATE DATABASE AFTER SUBMITTING POST
	
	int board = Integer.parseInt(request.getParameter("board_num").replace("\\", "").replace("\"", "").toString()); 
	
	Statement stmt = conn.createStatement();
	
	// CHECK PERM
	
	String str = "SELECT isin.user, isin.board FROM isin WHERE isin.board = " + board + " AND isin.user = " + session.getAttribute("userid").toString();
	ResultSet result = stmt.executeQuery(str);
	if(!result.next()){
		throw new Exception();
	}	
	
	if(request.getParameter("input_text") != null){
		String inputText = request.getParameter("input_text").toString();
		inputText = inputText.replace("\"", "\"\"");
		inputText = inputText.replace("\\", "\\\\");
		String searchPostsForIDStr = "SELECT MAX(id) AS max FROM post";
		ResultSet searchPosts = stmt.executeQuery(searchPostsForIDStr);
		searchPosts.next();
		int newID = searchPosts.getInt("max") + 1;
		int done = 0;
		
		int addPost =0;
		int addPosts = 0;
		String addPostsStr="";
		String addPostStr="";
		
		//check perms for whitelist
		String checkperms = "SELECT permission_level FROM user WHERE user.id = \"" + session.getAttribute("userid").toString()+"\"";
		ResultSet resultForPerms = stmt.executeQuery(checkperms);
		
		String perms = "";
		while(resultForPerms.next()){
			perms = resultForPerms.getString("permission_level");
		}
		
		inputText = inputText.replace("<", "&lt;");
		if(perms.equals("great_white") || perms.equals("water_hydar")){
			inputText=inputText.replaceAll("&lt;href", "<href").replaceAll("&lt;img", "<img").replaceAll("&lt;br", "<br");
		}
		
		
		// BOT COMMANDS
		if(inputText.substring(0,1).equals("/")){
			
			// /help
			if(done == 0 && inputText.equals("/help")){
				inputText = "User Commands: <br>(Unofficial boards only): /leave<br>(board owner only): /admin<br>";
				done = 1;
			}
			// /leave
			if(done == 0 && inputText.equals("/leave")){
				inputText = "Leaving board...";
				response.sendRedirect("LeaveBoard.jsp?board_num="+board);
				done = 1;
			}
			// /forge
			if(done == 0 && inputText.equals("/forge")){
				//ProcessBuilder pb = new ProcessBuilder("python", "py").inheritIO();
				
				addPostStr="INSERT INTO post(`contents`, `id`, `board`, `created_date`)"
							+ " VALUES (\"Getting Forge data\", " + newID + ", " + board + ", " + System.currentTimeMillis() + ")";
				addPost = stmt.executeUpdate(addPostStr);
				
				addPostsStr="INSERT INTO posts(`user`, `post`, `board`)"
						+ " VALUES (" + session.getAttribute("userid").toString() + ", " + newID + ", " + board + ")";
				addPosts = stmt.executeUpdate(addPostsStr);
				newID += 1;
				inputText = "";
				Process p = Runtime.getRuntime().exec("python bots/HydarForgeCalculator_0.2.5.4.py");
				p.waitFor();
				BufferedReader bfr = new BufferedReader(new InputStreamReader(p.getInputStream()));
				String line = bfr.readLine();
				while (line != null) {
					inputText = inputText + line.replaceAll("\"", "\"\"") + "<br>";
					line = bfr.readLine();
				}
				done = 1;
			}
			// /bits
			if(done == 0 && inputText.equals("/bits")){
				//ProcessBuilder pb = new ProcessBuilder("python", "py").inheritIO();
				
				addPostStr="INSERT INTO post(`contents`, `id`, `board`, `created_date`)"
							+ " VALUES (\"Getting Bits data\", " + newID + ", " + board + ", " + System.currentTimeMillis() + ")";
				addPost = stmt.executeUpdate(addPostStr);
				
				addPostsStr="INSERT INTO posts(`user`, `post`, `board`)"
						+ " VALUES (" + session.getAttribute("userid").toString() + ", " + newID + ", " + board + ")";
				addPosts = stmt.executeUpdate(addPostsStr);
				newID += 1;
				inputText = "";
				Process p = Runtime.getRuntime().exec("python bots/HydarBitsCalculator.py");
				p.waitFor();
				BufferedReader bfr = new BufferedReader(new InputStreamReader(p.getInputStream()));
				String line = bfr.readLine();
				while (line != null) {
					inputText = inputText + line.replaceAll("\"", "\"\"") + "<br>";
					line = bfr.readLine();
				}
				done = 1;
			}
			
			//administrator commands
			String checkIfAdmin = "SELECT board.creator FROM board WHERE board.number =" + board;
			ResultSet checkAdmin = stmt.executeQuery(checkIfAdmin);
			int boardCreator = -1;
			while(checkAdmin.next()){
				boardCreator = checkAdmin.getInt("board.creator");
			}
			if(done == 0 && boardCreator == Integer.parseInt(session.getAttribute("userid").toString())){
				// /admin
				if(inputText.equals("/admin")){
					inputText = "Admin commands: <br>/kick (user id)<br>/invite (user id)<br>/deleteboard<br>/inviteonly (on/off)";
					done = 1;
					
				}
				
				// commands that take an input
				if(inputText.indexOf(" ") != -1){
					// /invite
					if(inputText.substring(0, inputText.indexOf(" ")).equals("/invite")){
						int invitedUser = Integer.parseInt(inputText.substring(inputText.indexOf(" ") + 1));
						inputText = "Sent invite to user #" + invitedUser;
						response.sendRedirect("InviteUser.jsp?invitedID=" + invitedUser + "&board_num="+board);
						done = 1;
					}
					
					// /kick
					if(inputText.substring(0, inputText.indexOf(" ")).equals("/kick")){
						int kickedUser = Integer.parseInt(inputText.substring(inputText.indexOf(" ") + 1));
						inputText = "Removed user #" + kickedUser;
						response.sendRedirect("KickUser.jsp?kickID=" + kickedUser + "&board_num="+board);
						done = 1;
					}
					
					// /inviteonly
					if(inputText.substring(0, inputText.indexOf(" ")).equals("/inviteonly")){
						String onOff = inputText.substring(inputText.indexOf(" ") + 1);
						if(onOff.toLowerCase().equals("on")){
							inputText = "Invite only has been switched to ON (users must have an invite to join this board)";
							response.sendRedirect("EditBoardSettings.jsp?inviteonly=on&board_num="+board);
						}
						if(onOff.toLowerCase().equals("off")){
							inputText = "Invite only has been switched to OFF (anyone with the board ID can join this board now)";
							response.sendRedirect("EditBoardSettings.jsp?inviteonly=off&board_num="+board);
						}
						done = 1;
					}
					
				}
				
				
				// /delete - prompt comfirmation
				if(inputText.equals("/deleteboard")){
					inputText = "Requested to delete board. Type \"\"/confirm-delete\"\" to confirm and delete this board.";
				}
				
				// delete - actual
				if(inputText.equals("/confirm-delete")){
					inputText = "Deleting board...";
				}
				
				
				
			}
			
			
			
		}
		addPostStr="INSERT INTO post(`contents`, `id`, `board`, `created_date`)"
					+ " VALUES (\"" + inputText + "\", " + newID + ", " + board + ", " + System.currentTimeMillis() + ")";
		addPost = stmt.executeUpdate(addPostStr);
		
		addPostsStr="INSERT INTO posts(`user`, `post`, `board`)"
				+ " VALUES (" + session.getAttribute("userid").toString() + ", " + newID + ", " + board + ")";
		addPosts = stmt.executeUpdate(addPostsStr);
		
		if(done == 0 && inputText.equals("Deleting board...")){
			response.sendRedirect("DeleteBoard.jsp?board_num="+board);
		}
		
	}
	
	//REDIRECT BACK TO PREVIOUS BOARD
	
	out.print("</form>");
	//response.sendRedirect("Homepage.jsp?board="+board);
	
}catch(Exception e){
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
