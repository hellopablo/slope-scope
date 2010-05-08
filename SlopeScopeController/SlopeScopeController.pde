//---------------------------------------------------------------
//  
//  WIIIR
//  
//  This sketch interprets incoming values from a WiiMote connected via DarwiinRemoteOSC and
//  connects with an Arduino via USB Serial to manipulate servo motors on the tilt and pan axis
//  
//  Author:   Pablo de la Pena
//  version:  3.0
//  dated:    8th May 2010
//  
//---------------------------------------------------------------

//  Import libraries
import oscP5.*;
import netP5.*;
import processing.serial.*;

//  Create instances
OscP5 osc;
NetAddress myRemoteLocation;
Serial port;

//  define constants
static final int    WAIT_TIME     = 30;   //  Slow things down to allow servo/serial to behave itself
static final int    FRAME_RATE    = 20;   //  Frame rate of the sketch
static final int    WIDTH         = 1000;  //  Width of the sketch
static final int    HEIGHT        = 600;  //  Height rate of the sketch
static final String FONT          = "HelveticaNeue-Light-15.vlw";


//  Other variables
float   [] ir;
PFont   font;  // need a font if we're going to use text
float   tempavX, tempavY;
int     avX, avY;
int     numPoints, noPoints, lastCommand;
char    tiltGo, panGo, finalCommand;
String  panEng, tiltEng;

// Servo speeds
static final char LEFT_SLOW     = 'A';
static final char LEFT_MEDIUM   = 'B';
static final char LEFT_FAST     = 'C';

static final char RIGHT_SLOW    = 'D';
static final char RIGHT_MEDIUM  = 'E';
static final char RIGHT_FAST    = 'F';

static final char UP_SLOW       = 'G';
static final char UP_MEDIUM     = 'H';

static final char DOWN_SLOW     = 'I';
static final char DOWN_MEDIUM   = 'J';

static final char STOP_PAN      = 'K';
static final char STOP_TILT     = 'L';

Boolean wiiIrTransmitting       = false;
Boolean stopOnce                = false;
Boolean noTransmit              = false;


void setup() {
  
  //  Set up the environment
  size(WIDTH,HEIGHT);
  frameRate(FRAME_RATE);
  
   // Connect to the Arduino
  port = new Serial(this, Serial.list()[0], 115200);
 
  //  Open an UDP port for listening to incoming OSC messages from darwiinremoteOSC
  //  This code copied from sample sketch - not entirely sure what it does
  //  Start copied code ---
  
    osc = new OscP5(this, 5600);
    osc.plug(this, "ir", "/wii/irdata");
    osc.plug(this, "connected", "/wii/connected");
  
    ir = new float[12];
  
  //  --- end copied code
  
  // Setup a font if we need one
  font = loadFont(FONT); 
  textFont(font); 

}

//---------------------------------------------------------------
//  
//  HELPER FUNCTIONS
//  
//---------------------------------------------------------------

//  connected()
//  functionality unknown, copied from example.
void connected(int theFlag) {
  if(theFlag==1) {
    println("wii connected");
  } 
  else {
    wiiIrTransmitting = false;
    println("wii DISCONNECTED");
  }
}

// darwiinremoteOSC sends 12 floats containing the x,y and size values for 
// 4 IR spots the wiimote can sense. values are between 0 and 1 for x and y
// values for size are 0 and bigger. if the size is 15 or 0, the IR point is not 
// recognized by the wiimote.
void ir(
float f10, float f11,float f12, 
float f20,float f21, float f22,
float f30, float f31, float f32,
float f40, float f41, float f42
) {
  wiiIrTransmitting = true;
  ir[0] = f10;
  ir[1] = f11;
  ir[2] = f12;
  ir[3] = f20;
  ir[4] = f21;
  ir[5] = f22;
  ir[6] = f30;
  ir[7] = f31;
  ir[8] = f32;
  ir[9] = f40;
  ir[10] = f41;
  ir[11] = f42;
}






//---------------------------------------------------------------
//  
//  DRAW FUNCTION
//  
//---------------------------------------------------------------
void draw() {
  
  //  Clear the screen and do some admin...
  background(0);
  textAlign(LEFT);
  float [] temp = ir;
  
  if (!wiiIrTransmitting) {
   fill(255);
   textAlign(CENTER);
   text("Please connect WiiMote using DarwiinOSC",width/2,height/2);
   if (!stopOnce) {
     stopOnce = true;
     println("stopping");
     send('r');
   }
   return; 
  }
  
  //  clear variables
  avX = 0;
  avY = 0;
  tempavX = 0;
  tempavY = 0;
  numPoints = 0;
  stopOnce = false;

  
  //  Draw the lines and tolerance box
  drawGrid();
    
  //  Loop thorugh all our points
  //  remembering each block of 3 values represents the X, Y and Z of a single point.
  //  Get the average for X and Y to deal with multiple sources
  for(int i=0;i<12;i+=3) {
    
    if(ir[i+2]<15) { // a size >=15 indicates: IR point not available
      
      numPoints++;
      tempavX += ir[i];
      tempavY += ir[i+1];
    
    }
    
  }  //  end for loop



  text("Number of points: " + numPoints, 25, 35);
  
  if (noTransmit) {
    textAlign(CENTER);
    text("SERIAL COMMUNICATION DISABLED",width/2,height/2-10);
    text("press b to toggle serial communication",width/2,height/2+30);
    textAlign(LEFT);
  }
    
  // Only calculate anything if we have points to work with  
  if (numPoints == 0) {
    send('r');
    text("Pan:  STOP", 25, 55);
    text("Tilt: STOP", 25, 75); 
    return;
  }
  
  tempavX = tempavX/numPoints;
  tempavY = tempavY/numPoints;
  
  // map the points to a useable scale
  avX = int(map(tempavX, 0, 1, 0, WIDTH));
  avY = int(map(tempavY, 0, 0.75, 0, HEIGHT));
  
  // flip reverse the points
  avX = WIDTH - avX;
  avY = HEIGHT - avY;
      
  // Workout how we need to move here
  
  // PANNING
  if (avX > 450 && avX < 550)  //----------------- point is close enough to the centre
  {
    panGo = STOP_PAN;
    panEng = "STOP";
  }
  else if (avX < 450)  //------------------------- point is LEFT of the center
  {
    if (avX < 150)
    {
      panGo = RIGHT_FAST;
      panEng = "RIGHT_FAST";
    }
    else if (avX < 300)
    {
      panGo = RIGHT_MEDIUM;
      panEng = "RIGHT_MEDIUM";
    }
    else
    {
      panGo = RIGHT_SLOW;
      panEng = "RIGHT_SLOW";
    }
  }
  else if (avX > 550)  //------------------------- point is LEFT of the center
  {
    if (avX > 850)
    {
      panGo = LEFT_FAST; 
      panEng = "LEFT_FAST";
    }
    else if (avX > 700)
    {
      panGo = LEFT_MEDIUM;
      panEng = "LEFT_MEDIUM";
    }
    else
    {
      panGo = LEFT_SLOW;
      panEng = "LEFT_SLOW";
    }
  }
  
  
  
  // TILTING
  if (avY > 200 && avY < 400)  //----------------- point is close enough to the centre
  {
    tiltGo = STOP_TILT;
    tiltEng = "STOP";
  }
  else if (avY < 200)  //------------------------- point is ABOVE of the center
  {
    if (avY < 125)
    {
      tiltGo = UP_MEDIUM;
      tiltEng = "UP_MEDIUM";
    }
    else
    {
      tiltGo = UP_SLOW;
      tiltEng = "UP_SLOW";
    }
  }
  else if (avY > 400)  //------------------------- point is BELOW of the center
  {
    if (avY > 475)
    {
      tiltGo = DOWN_MEDIUM;
      tiltEng = "DOWN_MEDIUM";
    }
    else
    {
      tiltGo = DOWN_SLOW;
      tiltEng = "DOWN_SLOW";
    }
  }
  
  finalCommand = 'r';
  
  if (panGo == RIGHT_FAST && tiltGo == UP_MEDIUM) {
    finalCommand = 'a';
  } else if (panGo ==  RIGHT_MEDIUM && tiltGo == UP_MEDIUM) {
    finalCommand = 'b';  
  } else if (panGo ==  RIGHT_SLOW && tiltGo == UP_MEDIUM) {
    finalCommand = 'c'; 
  } else if (panGo ==  STOP_PAN && tiltGo == UP_MEDIUM) {
    finalCommand = 'd';  
  } else if (panGo ==  LEFT_SLOW && tiltGo == UP_MEDIUM) {
    finalCommand = 'e';  
  } else if (panGo ==  LEFT_MEDIUM && tiltGo == UP_MEDIUM) {
    finalCommand = 'f';  
  } else if (panGo ==  LEFT_FAST && tiltGo == UP_MEDIUM) {
    finalCommand = 'g';  
    
  } else if (panGo == RIGHT_FAST && tiltGo == UP_SLOW) {
    finalCommand = 'h';
  } else if (panGo ==  RIGHT_MEDIUM && tiltGo == UP_SLOW) {
    finalCommand = 'i';  
  } else if (panGo ==  RIGHT_SLOW && tiltGo == UP_SLOW) {
    finalCommand = 'j';  
  } else if (panGo ==  STOP_PAN && tiltGo == UP_SLOW) {
    finalCommand = 'k';  
  } else if (panGo ==  LEFT_SLOW && tiltGo == UP_SLOW) {
    finalCommand = 'l';  
  } else if (panGo ==  LEFT_MEDIUM && tiltGo == UP_SLOW) {
    finalCommand = 'm';  
  } else if (panGo ==  LEFT_FAST && tiltGo == UP_SLOW) {
    finalCommand = 'n';
    
  } else if (panGo == RIGHT_FAST && tiltGo == STOP_TILT) {
    finalCommand = 'o';
  } else if (panGo ==  RIGHT_MEDIUM && tiltGo == STOP_TILT) {
    finalCommand = 'p';  
  } else if (panGo ==  RIGHT_SLOW && tiltGo == STOP_TILT) {
    finalCommand = 'q';  
  } else if (panGo ==  STOP_PAN && tiltGo == STOP_TILT) {
    finalCommand = 'r';  
  } else if (panGo ==  LEFT_SLOW && tiltGo == STOP_TILT) {
    finalCommand = 's';  
  } else if (panGo ==  LEFT_MEDIUM && tiltGo == STOP_TILT) {
    finalCommand = 't';  
  } else if (panGo ==  LEFT_FAST && tiltGo == STOP_TILT) {
    finalCommand = 'u';
    
  } else if (panGo == RIGHT_FAST && tiltGo == DOWN_SLOW) {
    finalCommand = 'v';
  } else if (panGo ==  RIGHT_MEDIUM && tiltGo == DOWN_SLOW) {
    finalCommand = 'w';  
  } else if (panGo ==  RIGHT_SLOW && tiltGo == DOWN_SLOW) {
    finalCommand = 'x';  
  } else if (panGo ==  STOP_PAN && tiltGo == DOWN_SLOW) {
    finalCommand = 'y';  
  } else if (panGo ==  LEFT_SLOW && tiltGo == DOWN_SLOW) {
    finalCommand = 'z';  
  } else if (panGo ==  LEFT_MEDIUM && tiltGo == DOWN_SLOW) {
    finalCommand = 'A';  
  } else if (panGo ==  LEFT_FAST && tiltGo == DOWN_SLOW) {
    finalCommand = 'B';
    
  } else if (panGo == RIGHT_FAST && tiltGo == DOWN_MEDIUM) {
    finalCommand = 'C';
  } else if (panGo ==  RIGHT_MEDIUM && tiltGo == DOWN_MEDIUM) {
    finalCommand = 'D';  
  } else if (panGo ==  RIGHT_SLOW && tiltGo == DOWN_MEDIUM) {
    finalCommand = 'E';  
  } else if (panGo ==  STOP_PAN && tiltGo == DOWN_MEDIUM) {
    finalCommand = 'F';  
  } else if (panGo ==  LEFT_SLOW && tiltGo == DOWN_MEDIUM) {
    finalCommand = 'G';  
  } else if (panGo ==  LEFT_MEDIUM && tiltGo == DOWN_MEDIUM) {
    finalCommand = 'H';  
  } else if (panGo ==  LEFT_FAST && tiltGo == DOWN_MEDIUM) {
    finalCommand = 'I';
  }
  
  //  Encode the motion

  send(finalCommand);

  
  //  Draw all the text
  text("Pan:  " + panEng, 25, 55);
  text("Tilt: " + tiltEng, 25, 75);
  text("X: "+ avX, 25, 95);
  text("Y: "+ avY, 25, 115);
  
  // Draw the spot for visualising purposes
  fill(color(255));
  ellipse(avX, avY, 5, 5);
  
  //  slight pause....
  delay(WAIT_TIME);
  

}  //  end draw();

void drawGrid() {
  
  rectMode(CORNER);
  noStroke();
  
  // FAST ZONES
  fill(#666666);
  rect(0,0,150,height);
  rect(width-150,0,150,height);
  
  // MEDIUM ZONE
  fill(#555555);
  rect(150,0,150,height);
  rect(width-300,0,150,height);
  
  // SLOW ZONES
  fill(#333333);
  rect(300,0,150,height);
  rect(width-450,0,150,height);
  
  
  // STOP ZONE
  fill(#000000);
  rect(450,0,100,height);
  
  fill(0);
  
  stroke(#777777);
  line(0, height/2, width, height/2);  // X
  line(width/2, 0, width/2, height);  // Y
  line(0,125,width, 125);
  line(0,200,width, 200);
  line(0,400,width, 400);
  line(0,475,width, 475);
  
  stroke(#555555);
  fill(#333333);
  rect(20,18,150,103);
  fill(#cccccc);
  noStroke();
  
  wiiIrTransmitting = false;
}

void keyReleased() {

 if (key == 'b' || key == 'B') {
    if (noTransmit) {
     noTransmit = false; 
    } else {
     noTransmit = true; 
    }
 } 
}

void send(char output) {
  if (!noTransmit) {
    println(output);
    port.write(output); 
  }
}
