<%@page import="java.util.EnumMap"%>
<%@page import="java.util.concurrent.ThreadLocalRandom"%>
<%@page import="java.util.stream.Collectors, static java.util.stream.Collectors.toMap"%>
<%@page import="static java.util.stream.Collectors.joining"%>
<%@page import="java.util.ArrayList"%>
<%@page import="java.io.IOException"%>
<%@page import="java.util.stream.Stream"%>
<%@page import="java.util.Collections"%>
<%@page import="xyz.hydar.ee.HydarWS"%>
<%@page import="java.util.List"%>
<%@page import="java.util.Set"%>
<%@page import="java.util.Comparator"%>
<%@page import="java.util.concurrent.locks.ReentrantLock"%>
<%@page import="java.util.Map"%>
<%@page import="java.util.concurrent.ConcurrentHashMap"%>
<%@page import="java.util.stream.IntStream"%>
<%@page import="java.util.Arrays"%>
<%@ page language="java"%>
<%@ page import="javax.servlet.http.*,javax.servlet.*"%>
<%@ page contentType="text/html; charset=UTF-8" %>
<%@ include file="SkeleAdd.jsp" %>
<%!
static enum Suit{
	HEARTS, DIAMONDS, CLUBS, SPADES;
	@Override
	public String toString(){
		return switch(this){
			case HEARTS->"♥";
			case DIAMONDS->"♦";
			case CLUBS->"♣︎";
			case SPADES->"♠";
		};
	}
};
static record Card(Suit suit, int rank){
	static final int[] ranks = IntStream.range(1,14).toArray();
	static final EnumMap<Suit,List<Card>> CARDS=Arrays.stream(Suit.values())
		.collect(
			toMap(
				x->x,
				x->Arrays.stream(ranks).mapToObj(y->new Card(x,y)).toList(),
				(x,y)->x,
				()->new EnumMap<>(Suit.class)
			)
		);
	static final EnumMap<Suit,List<Card>> IMPOSTORS = Arrays.stream(Suit.values())
		.collect(
			toMap(
				x->x,
				x->Arrays.stream(ranks).mapToObj(y->new Card(x,-y)).toList(),
				(x,y)->x,
				()->new EnumMap<>(Suit.class)
			)
		);
	static Card JOKER = new Card(Suit.HEARTS,-1);
	static Card of(Suit suit, int rank){
		return CARDS.get(suit).get(rank-1);
	}
	static Card negative(Suit suit, int rank){
		return IMPOSTORS.get(suit).get(-rank-1);
	}
	static List<Card> deal(int n, int jokers){
		List<Card> deck = Stream.concat(
				CARDS.values().stream().flatMap(List::stream)
				//,Stream.generate(()->new Card(Suit.HEARTS,-1)).limit(jokers)
				,Collections.nCopies(jokers, JOKER).stream()
			).collect(Collectors.toCollection(ArrayList::new));
		Collections.shuffle(deck);
		return deck.subList(0,n);
	}
	public static Suit findSuit(List<Card> hand){
		Suit theSuit=null;
		for(Card c:hand){
			if(c.suit()!=Suit.HEARTS&&theSuit==null){
				theSuit=c.suit();
			}else if(theSuit!=c.suit() && c.suit()!=Suit.HEARTS && theSuit!=null)
				return null;
		}
		return theSuit==null?Suit.HEARTS:theSuit;
	}
	public static double multiplier(Suit s1, Suit s2){
		return switch(s1){
			case HEARTS -> switch(s2){
				case HEARTS->1;
				case DIAMONDS->0;
				case CLUBS->0;
				case SPADES->0;
			};
			case DIAMONDS-> switch(s2){
				case HEARTS->99;
				case DIAMONDS->1;
				case CLUBS->0.5;
				case SPADES->2;
			};
			case CLUBS-> switch(s2){
				case HEARTS->99;
				case DIAMONDS->2;
				case CLUBS->1;
				case SPADES->0.5;
			};
			case SPADES-> switch(s2){
				case HEARTS->99;
				case DIAMONDS->0.5;
				case CLUBS->2;
				case SPADES->1;
			};
		};
	}
	@Override
	public String toString(){
		if(this==JOKER)
			return "joker";
		return switch(rank){
			case 1->"A";
			case 13->"K";
			case 12->"Q";
			case 11->"J";
			default->""+rank;
		}+suit;
	}
	public boolean joker(){
		return suit==Suit.HEARTS && rank == -1;
	}
}
static class Game{
	volatile List<Card> active;
	volatile boolean alive=true;
	final Player p1,p2;//uids
	//on selected cards, lock and set active to these cards IF its null, otherwise fight those cards
	//maybe atomicreference instead??
	volatile Player activePlayer;//player on battlefield
	volatile int rounds=0;
	final ReentrantLock turnLock = new ReentrantLock();
	public Game(Player p1, Player p2) throws IOException{
		this.p1=p1;
		this.p2=p2;
		p1.game=this;
		p2.game=this;
		p1.opp=p2;
		p2.opp=p1;
		List<Card> hands = Card.deal(10,2);
		p1.hand = hands.subList(0,hands.size()/2);
		p2.hand = hands.subList(hands.size()/2,hands.size());
		printHands();
		p1.print("msg:Your turn...");
		p1.print("turn:start");
		p2.print("msg:Your turn...");
		p2.print("turn:start");
		//send that game has started + hands
	}
	private String formatCards(List<Card> cards){
		return cards.stream().map(Card::toString).collect(joining(","));
	}
	public void printHands() throws IOException{
		if(active!=null){
			p1.print("msg:"+"Cards down "+(p1==activePlayer?"(yours) ":"(enemy's) ")+active);
			p2.print("msg:"+"Cards down: "+(p2==activePlayer?"(yours) ":"(enemy's) ")+active);
			p1.print("active:"+formatCards(active));
			p2.print("active:"+formatCards(active));
		}
		p1.print("msg:Your hand: "+p1.hand);
		p1.print("hand:"+formatCards(p1.hand));
		p2.print("msg:Your hand: "+p2.hand);
		p2.print("hand:"+formatCards(p2.hand));
	}
	public List<Card> showdown(List<Card> active, List<Card> challenge) throws IOException{
		rounds++;
		var rng=ThreadLocalRandom.current();
		Player challengePlayer = activePlayer==p1?p2:p1;
		Suit activeSuit = Card.findSuit(active);
		Suit challengeSuit = Card.findSuit(challenge);
		int activeTotal = active.stream().mapToInt(x->x.rank()).sum();
		//activePlayer.print("msg:"+"Your cards have a total of "+activeTotal+" power");
		//challengePlayer.print("msg:"+"The enemy's cards have a total of "+activeTotal+" power");
		int challengeTotal = challenge.stream().mapToInt(x->x.rank()).sum();
		//challengePlayer.print("msg:"+"Your cards have a total of "+challengeTotal+" power");
		//activePlayer.print("msg:"+"The enemy's cards have a total of "+challengeTotal+" power");
		double multiplier = Card.multiplier(activeSuit,challengeSuit);
		//activePlayer.print("msg:"+"Your cards are multiplied by "+multiplier+" for a total of "+activeTotal*multiplier+" power");
		//challengePlayer.print("msg:"+"The enemy's cards are multiplied by "+multiplier+" for a total of "+activeTotal*multiplier+" power");
		boolean tie=activeTotal * multiplier == challengeTotal;
		boolean activeWin = activeTotal * multiplier > challengeTotal;
		String activeResult = "msg:(You)"+active+" x "+multiplier+" = "+ (activeTotal*multiplier)+"\n vs. (Enemy) "+challenge +" = " +challengeTotal;
		String challengeResult = "msg:(Enemy)"+active+" x "+multiplier+" = "+ (activeTotal*multiplier)+"\n vs. (You) "+challenge +" = " +challengeTotal;
		activePlayer.print(activeResult);
		challengePlayer.print(challengeResult);
		if(tie){
			boolean activePick = rng.nextDouble()>0.5;//h/t pick
			boolean coin = rng.nextDouble()>0.5;//h/t roll
			activeWin = activePick==coin;
			activePlayer.print("msg:Tie, you pick: "+(activePick?"heads":"tails")+", coin: "+(coin?"heads":"tails"));
			challengePlayer.print("msg:Tie, you pick: "+(activePick?"tails":"heads")+", coin: "+(coin?"heads":"tails"));
			activePlayer.print("coin:"+activePick+","+coin);
			challengePlayer.print("coin:"+!activePick+","+coin);
		}
		activePlayer.print("msg:"+(!activeWin?"You lose this round!":"You win this round!"));
		challengePlayer.print("msg:"+(activeWin?"You lose this round!":"You win this round!"));
		return activeWin ? active : challenge;
	}
	//Return a version of the deployed cards(with) with jokers and aces replaced
	public List<Card> replaceJokersAces(Player player, List<Card> with, List<Card> against) throws IOException{
		List<Card> newCards = new ArrayList<>();
		Suit ownSuit = Card.findSuit(with);
		ThreadLocalRandom rng = ThreadLocalRandom.current();
		for(Card c:with){
			if(c==Card.JOKER){
				int dice1=rng.nextInt(1,7), dice2=rng.nextInt(1,7);
				player.opp.print("msg:Dice rolls(Joker): "+dice1+", "+dice2);
				player.print("msg:Dice rolls(Joker): "+dice1+", "+dice2);
				player.opp.print("dice:enemy,joker,"+dice1+","+dice2);
				player.print("dice:you,joker,"+dice1+","+dice2);
				Suit newSuit = (ownSuit!=Suit.HEARTS || rounds==0)? ownSuit:switch(Card.findSuit(against)){
					case HEARTS->Suit.HEARTS;
					case DIAMONDS->Suit.CLUBS;
					case CLUBS->Suit.SPADES;
					case SPADES->Suit.DIAMONDS;
				};
				if(dice1==dice2){
					Card nc=Card.negative(newSuit,-(dice1+dice2));
					newCards.add(nc);
					player.opp.print("msg:Your opponent found the IMPOSTOR!! ("+nc+")");
					player.print("msg:You found the IMPOSTOR!! ("+nc+")");
					
				}else{
					Card nc=Card.of(newSuit,(dice1+dice2));
					newCards.add(nc);
					player.opp.print("msg:Your opponent didn't find the impostor. ("+nc+")");
					player.print("msg:Your didn't find the impostor. ("+nc+")");
				}
			}else if(c.rank==1){

				int dice1=rng.nextInt(1,7), dice2=rng.nextInt(1,7);
				Card nc=Card.of(ownSuit,(dice1+dice2));
				player.opp.print("msg:Dice rolls(Ace): "+dice1+", "+dice2);
				player.print("msg:Dice rolls(Ace): "+dice1+", "+dice2);
				player.opp.print("dice:enemy,ace,"+dice1+","+dice2);
				player.print("dice:you,ace,"+dice1+","+dice2);
				player.opp.print("msg:Enemy ace becomes: ("+nc+")");
				player.print("msg:Your ace becomes: ("+nc+")");
				
				newCards.add(nc);
			}
			else newCards.add(c);
		}
		return Collections.unmodifiableList(newCards);
	}
	public void process(Player player, String move) throws IOException{
		//formatting
		String[] cmds=move.split(":",2);
		if(cmds.length!=2){
			player.print("err:BAD_CMD");
			player.print("turn:start");
			return;
		}
		String cmd = cmds[0];
		String text = cmds[1];
		if(text.length()==0){
			player.print("err:BAD_CMD");
			player.print("turn:start");
			return;
		}
		//move contains the cards selected
		if(cmd.equals("select")){
			turnLock.lock();
			try{
				//unselected cards are the ones that will be left in hand
				List<Integer> selected = Arrays.asList(text.split(",")).stream().map(Integer::parseInt).toList();
				List<Integer> unselected = IntStream.range(0,player.hand.size()).boxed().filter(x->!selected.contains(x)).toList();
				
				List<Card> challenging=null;
				Player opp = player==p1?p2:p1;
			
				if(activePlayer==null){
					List<Card> tmpActive = selected.stream().map(player.hand::get).toList();
					if(Card.findSuit(tmpActive)==null){
						player.print("msg:Mixed hand. Please draw again");
						player.print("err:MIXED_HAND");
						player.print("turn:start");
						return;
					}
					active=tmpActive;
					activePlayer=player;
				}else{
					if(activePlayer==player){
						player.print("msg:Not your turn.");
						player.print("err:WRONG_TURN");
						return;
					}else{
						List<Card> tmpChallenging = selected.stream().map(player.hand::get).toList();
						if(Card.findSuit(tmpChallenging)==null){
							player.print("msg:Mixed hand. Please draw again");
							player.print("err:MIXED_HAND");
							player.print("turn:start");
							return;
						}
						challenging = tmpChallenging;
					}
				}
				player.hand = unselected.stream().map(player.hand::get).toList();
				//both hands in play
				if(challenging==null){
					//process aces and jokers on active
					activePlayer.print("msg:Your cards have been placed.");
					opp.print("msg:Your opponent has placed cards.");
				}else{
					//process aces and jokers on challenging
					if(challenging.stream().anyMatch(x->x==Card.JOKER || x.rank==1)){
						challenging = replaceJokersAces(activePlayer.opp, challenging, active);
					}
					//process aces and jokers on active
					if(active.stream().anyMatch(x->x==Card.JOKER || x.rank==1)){
						active = replaceJokersAces(activePlayer, active, challenging);
					}
					active = showdown(active, challenging);
					if(active==challenging){ 
						activePlayer = player;
						if(opp.hand.isEmpty()){
							opp.print("msg:"+"You lose!");
							player.print("msg:"+"You win!");
							end();
							return;
						}
					}else{
						if(player.hand.isEmpty()){
							player.print("msg:"+"You lose!");
							opp.print("msg:"+"You win!");
							end();
							return;
						}
					}
				}
				if(challenging!=null)
				printHands();
				(p1==activePlayer?p2:p1).print("turn:start");//new challenger
			}
			finally{
				turnLock.unlock();
			}
		}
		
		return;
	}
	public void dropPlayer(Player player) throws IOException{
		try{
			Player opp=player==p1?p2:p1;
			if(alive){
				opp.print("msg:Opponent disconnected.");
				opp.print("msg:You win!");
			}
		}finally{
			end();
		}
	}
	public void end() throws IOException{
		if(!alive)return;
		alive=false;
		try{
			p1.close();
		}finally{
			p2.close();
		}
	}
}
public static class Player extends HydarWS.Endpoint{
	public volatile int id;
	public volatile String username;
	public volatile Game game;
	public volatile Player opp;
	public volatile List<Card> hand;
	public Player(HydarWS ws){
		super(ws);
	}
	@Override
	public void onOpen() throws IOException{
		print("msg:Connected!");
		id=(Integer)session.getAttribute("userid");
		username=(String)session.getAttribute("username"); 
	}
	@Override
	public void onClose() throws IOException{
		queueLock.lock();
		try{
			if(queue==this)queue=null;
			if(game!=null){
				game.dropPlayer(this);
			}
			
		}finally{
			queueLock.unlock();
		}
	}
	@Override
	public void onMessage(String msg) throws IOException{
		Integer uidTest=(Integer)session.getAttribute("userid");
		if(uidTest==null || uidTest!=id){
			close();
			return;
		}
		String cmd = msg.split(":",2)[0];
		if(cmd.equals("queue")){
			queueLock.lock();
			try{
				if(queue!=null && queue!=this){
					print("msg:Found game: "+queue.username+"...");
					queue.print("msg:Found game: "+username+"...");
					Game g = new Game(this,queue);
				}else if(queue==null){
					queue=this;
					print("msg:Queued...");
				}else if(queue==this){		
					print("msg:Not Queued...");
					close();
				}
			}finally{
				queueLock.unlock();
			}
		}else if(cmd.equals("ping")){
			
		}else if(game!=null){
			game.process(this,msg);
		}
	}
}
//static Map<Integer,Game> activeGames = new ConcurrentHashMap<>();
static ReentrantLock queueLock = new ReentrantLock();
static volatile Player queue;
static{
	HydarWS.registerEndpoint("TestHydarGame.jsp", Player.class);
}
%>
<%

%>
<!DOCTYPE html>
<html><body>
<div style='height:360px;top:0px;position:relative;background:lightgray;overflow:scroll;display: flex; flex-direction: column-reverse;'>
	<pre id='chat'></pre>
</div>

<div id='active' hidden=1>
Active Cards:<br>
	<div style='display:inline'>
	[    <a> 1</a>       ]
	</div>
</div>

<div id='turn' hidden=1 style='cursor:pointer'>
	<br>
	Your hand:
	<br>
	<div onclick='this.children[1].checked^=1;return false;' style='display:inline'>
	[<a> 1</a>
	<input type="checkbox" style="pointer-events:none">]
	</div>
</div>
<script>
let turnElem=document.getElementById("turn");
let activeElem=document.getElementById("active");
for(var i=0;i<27;i++){
	turnElem.appendChild(turnElem.querySelector("div").cloneNode(true));
	activeElem.appendChild(activeElem.querySelector("div").cloneNode(true));
}
let submitHand=document.createElement("button");
submitHand.type="submit";
submitHand.innerText="Send";
submitHand.onclick=()=>sendTurn(turnElem);
turnElem.appendChild(submitHand);
var myHostname = window.location.hostname;
var scheme = document.location.protocol==="https:"?"wss":"ws";
serverUrl = scheme + "://" + myHostname + ":"+document.location.port+"/TestHydarGame.jsp?";
var id=new URLSearchParams(document.location.search).get("HYDAR_sessionID");
function chat(str){
	document.getElementById("chat").innerText+=str+"\n";
}
if(id)serverUrl+="HYDAR_sessionID="+id+"&";
console.log("Connecting to server: "+serverUrl);
chat("Connecting...");
var connection = new WebSocket(serverUrl);
var timer=null;
var hand=[];
var active=[];
connection.onopen = function(_evt) {
	clearTimeout(timer);
	chat("Opened.");
	connection.send("queue:hydar");
	timer = setInterval(()=>connection.send("ping:hydar"),7000);
}
connection.onclose=function(_evt){
	clearTimeout(timer);
	hideMove("turn");
	hideMove("active");
	chat("Disconnected.");
}
connection.onerror = function(evt) {
	clearTimeout(timer);
	hideMove("turn");
	hideMove("active");
	chat("Disconnected(error).");
}
connection.onmessage = async function(evt) {
	let cmd=evt.data.split(":")[0];
	switch(cmd){
	case "msg":
		chat(evt.data.replace("msg:",""));
		break;
	case "turn":
		showMove("turn",hand);
		break;
	case "active":
		active=evt.data.split(":")[1].split(",");
		showMove("active",active);
		break;
	case "hand":
		hand=evt.data.split(":")[1].split(",");
		break;
	}
}
//commands s->c
//turn:start
//round:win,lose
//game:win,lose
//hand:C1,H2,...
//active:D4,H4,...
//dice:6,5(no for now)
//
//msg:
function sendTurn(e){
	let turn=[]
	for(let [i,box] of e.querySelectorAll("input").entries()){
		if(box.checked)
			turn.push(i)
		box.checked=false;
		if(i>=hand.length)
			break;
	}
	if(turn.length==0)
		return false;
	connection.send("select:"+turn.join());
	hideMove("turn");
	return false;
}
function hideMove(element){
	document.getElementById(element).hidden=1;
}
function showMove(element, cards){
	let turn_=document.getElementById(element);
	for(let [i,caption] of turn_.querySelectorAll("a").entries()){
		if(i>=cards.length){
			caption.hidden=true;
		}else{
			caption.hidden=false;
			caption.innerText = cards[i];
			caption.style.color=(cards[i].includes("♥")||cards[i].includes("♦"))?"red":"black";
		}
	}
	for(let [i,box] of turn_.querySelectorAll("input").entries()){
		if(i>=cards.length){
			box.hidden=true;
		}else box.hidden=false;
	}
	for(let [i,div] of turn_.querySelectorAll("div").entries()){
		if(i>=cards.length)
			div.style.display="none";
		else{
			div.style.display="inline";
		}
	}
	turn_.hidden=false;
}
</script>


</body>
</html>
<%-- Hydar hydar hydar hydar--%>
<%-- js that connects to this endpoint, sends queue msg, interprets incoming msgs, etc--%>