/*
* #################
* # MONICHROMITOR #
* #################
* 
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
* Copyright (C) 2016 Nicola Ariutti
* 
* This program is free software: you can redistribute it and/or 
* modify it under the terms of the GNU General Public License as 
* published by the Free Software Foundation, either version 3 
* of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful, 
* but WITHOUT ANY WARRANTY; without even the implied warranty of 
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
* See the GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License 
* along with this program. If not, see <http://www.gnu.org/licenses/>.
*
* This sketch make use of oscP5 library for Processing by Andreas Schlegel 
* (http://www.sojamo.de/libraries/oscP5/)
*
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
* A little sketch we made to simulate a computer automatically 
* writing on a monoschrome monitor. 
* This virtual screen is made up of 24 row and 40 columns.
* 
* To make make the computer automatically write on the virtual screen
* you have to write text insidea script file. 
* This file is called "script.txt" and is contained inside the 'data' folder.
* Script can also contain commands to make the computer do special
* movements and function. 
* Each command in its own separated row, preceded by a '#' character.
* 
* Script COMMANDS are:
* - clear: to clear the virtual screen completely and show a single prompt.
* - wait: this is the only command that takes a number as an argument. This number
*          represent the number of seconds the computer has to wait before executing
*          next operation.
* - linefeed: This command is a linefeed and carriage return command.
* - clearline: This command makes the line the cursor is in to be cleared completely.
* - restart: This command makes the program to read the script from the start.
*
* You can change the text color choosing among three different phosphors (GREEN, AMBER, WHITE).
* You can also change the PROMPT, modifying the corresponding string.
*
* OSC protocol is used to send messages to a PureData patches to synthetize sounds.
*/

/* OSC */
import oscP5.*;
import netP5.*;
OscP5 oscP5;
NetAddress myRemoteLocation;

/* SCREEN & TEXT */
int rows = 24;
int cols = 40;
int rowIdx, colIdx;
color GREEN = color(0, 255, 0);      // P1 phosphor
color AMBER = color(245, 159, 20);   // P3 phosphor
color WHITE = color(255, 255, 255);  // P4 phosphor
color MONOCHROME = GREEN;
Cursor cursor;
char data[] = new char[cols * rows];
String prompt = "$> ";

/* FONT & SPRITESHEET */
PImage fonts;
int fontWidth = 8;
int fontHeight= 10;

/* SCRIPT */
String script[];
int lineIdx;
int lineChar;

/* WAITING */
int idleWaitTime = 1000; // ms unit time to wait during idle waiting
int charWaitTime = 25; // ms unit time to wait between characters writing
int waitTime = 0;
int waitValue; // this is the value passet to the 'wait' script command 
boolean bWaiting = false;
int previousTime;

// SETUP //////////////////////////////////////////////////
void setup() { 
  size(cols*fontWidth, rows*fontHeight);
  frameRate(30);
  
  fonts = loadImage("spritesheet.png");
  scriptLoad();
  screenClear();
  cursor = new Cursor(colIdx, rowIdx, fontWidth, fontHeight, 500);
  previousTime = millis();
  
  /* OSC setup */
  oscP5 = new OscP5(this, 12000);
  myRemoteLocation = new NetAddress("127.0.0.1", 12000);
}

// DRAW ///////////////////////////////////////////////////
void draw() {
  // UPDATE
  scriptRead( millis() );
  cursor.update( millis() );
  
  // DISPLAY
  background(0);
  screenShow();
  cursor.display();
  
  // uncomment to save frames:
  //saveFrame("frames/frame-####.png");
}

// SCRIPT OPS. ////////////////////////////////////////////
void scriptLoad() {
  lineIdx = 0;
  lineChar = 0;
  script = loadStrings("script.txt");
  if( script == null ) {
    println("\nloadString returned NULL");
    exit();
  } else {
    println("Script loaded!");
    println("Script contains " + script.length + " lines");
    
    for (int i = 0 ; i < script.length; i++) {
      print("line "+i+" has "+ script[i].length() + " characters");
      if( script[i].isEmpty() ) {
        // empty line
        println(";");
        continue;
      } else if( scriptIsCommand(i) ) {
        if( whatCommand(i) == -1) {
          print(" - INVALID COMMAND!");
          exit();
        } else {
          print(" - line "+i+" is a command! ( ");
          print( script[i] +" )");
        }
      } else {
        print(";");
      }
      println();      
    }
  }
}

void scriptRead( int time ) {
  if( bWaiting ) {
    menageWaiting( time );
  } else if( lineIdx < script.length ) { 
    if( script[ lineIdx ].isEmpty() ) {
      // empty line
      lineIdx++;
    } else if( scriptIsCommand( lineIdx )) {
      //debugA("found a command:");
      // Any commands in the script have already been 
      // evaluated during the script loading
      int opCode = whatCommand( lineIdx );
      // command execution
      switch( opCode ) {
        case 0: // #WAIT
          //debugA("WAIT command");
          bWaiting = true;
          waitTime = idleWaitTime;
          previousTime = time;
          //previousWaitTime = time;
          break;
        case 1: //#CLEAR
          //debugA("CLEAR command");
          waitTime = charWaitTime;
          waitValue = 1;
          bWaiting = true;
          previousTime = time;
          screenClear();
          cursor.move(colIdx, rowIdx);
          break;
        case 2: //#LINEFEED
          //debugA("LINEFEED command");
          rowIdx++;
          colIdx = 0;
          insertPrompt();
          cursor.move(colIdx, rowIdx);
          break;
        case 3: //#RESTART
          //debugA("RESTART command");
          screenClear();
          lineIdx = 0;
          lineChar = 0;
          break;
        case 4: //#CLEARLINE
          //debugA("CLEARLINE command");
          screenClearLine();
          cursor.move(colIdx, rowIdx);
        default:
          break;
      }    
      lineIdx ++;
    } else {
      // characters
      if(lineChar < script[ lineIdx ].length() ) {
        waitTime = charWaitTime;
        waitValue = 1;
        bWaiting = true;
        previousTime = time;
        copyCharacter( time );
        cursor.move(colIdx, rowIdx);
        emitSound("char");
      } else {
        lineChar = 0;
        lineIdx++;
        scriptRead( millis() );
      }    
    }
  } else {
    //debugA("End of the script");
    exit();
  }
}

boolean scriptIsCommand( int i ) {
  if( script[i].charAt(0) == '#' ) {
    // This script line is a COMMAND
    return true;
  }
  return false;
}

/*
* This function returns a numeric ID associated to a COMMAND.
* This function takes a script line index to examine 
* the COMMAND contained in it.
*/
int whatCommand( int i ) {
  int cmd = -1;
  // data la linea dello script da esaminare, 
  // ritorna una identificativo numerico per ciascun comando
  if( script[i].equals("#clear") ) {
    cmd = 1;
  } else if( script[i].equals("#linefeed") ) {
    cmd = 2;
  } else if( script[i].equals("#restart") ) {
    cmd = 3;
  } else if( script[i].equals("#clearline") ) {
    cmd = 4;
  } else if( script[i].length() > 5 ) { //#wait(
    String sub = script[i].substring(0, 6); 
    if( sub.equals("#wait(") ){
      cmd = 0;
      int lastIdx = script[i].lastIndexOf(')');
      waitValue = Integer.parseInt( script[i].substring(6, lastIdx) );
    }
  }
  return cmd;
}

void menageWaiting( int time ) {
  if( time - previousTime > waitTime*waitValue) {
    bWaiting = false;
    //debugA("Stop to wait");
  }
}

/* 
* A function to copy a single character from the script line
* to the corresponding position inside screen character table 
*/
void copyCharacter(int time) {
  //debugA("nello script trovo dei caratteri da STAMPARE");
  // is time to copy a new charachter
  int pos = rowIdx*cols + colIdx;
  data[ pos ] = script[ lineIdx ].charAt( lineChar );
  colIdx++;
  lineChar++;
}

// SCREEN OPS. ////////////////////////////////////////////
void screenClear() {
  //debugA("screenClear");
  // 'data' charachters initialization
  for (int i=0; i<data.length; i++) 
    data[i] = ' '; // 'space' character
  
  // insert prompt at line beginning
  rowIdx = 0;
  colIdx = 0;
  insertPrompt();
}

void screenClearLine() {
  for (int colIdx=0; colIdx<cols; colIdx++) {
    int pos = rowIdx * cols + colIdx; 
    data[ pos ] = ' '; // 'space' character
  }
  
  // inserisco il prompt nella prima stringa
  // dello schermo.
  colIdx = 0;
  insertPrompt();
}

void insertPrompt() {
  //debugA("insertPrompt");
  for(; colIdx<prompt.length(); colIdx++) {
    int pos = rowIdx*cols + colIdx;
    data[ pos ] = prompt.charAt( colIdx ); 
  }
  colIdx = prompt.length();
  // Uncomment to integrate waiting time 
  // with prompt appearance.
  //waitTime = charWaitTime;
  //waitValue = 1;
  //bWaiting = true;
  //previousTime = millis();
}

void screenShow() {
  int dstRow=0, dstCol=0, dstX=0, dstY=0;
  int srcRow=0, srcCol=0, srcX=0, srcY=0;
  int charIdx = -1;
  int max = rowIdx*cols + colIdx; 
  for(int i=0; i<max; i++) {
  //for(int i=0; i<data.length; i++) {
    charIdx = data[i];
    // posizione nello screen
    dstRow = i/cols;
    dstCol = i%cols;
    dstX = dstCol*fontWidth;
    dstY = dstRow*fontHeight;
    /* Spritesheet position */
    // spritesheet contains 16 rows with
    // 16 characters on each. 
    srcRow = (charIdx % 16);
    srcCol = (charIdx/16);
    srcX = srcRow*fontWidth;
    srcY = 160-fontHeight-(srcCol*fontHeight);
    PImage letter = fonts.get( srcX, srcY, fontWidth, fontHeight);
    tint( MONOCHROME );
    image(letter, dstX, dstY);
  }
}

// SOUND //////////////////////////////////////////////////
void emitSound( String s) {
  OscMessage myMessage = new OscMessage("/"+ s );
  oscP5.send(myMessage, myRemoteLocation);
}

// UTILITY ////////////////////////////////////////////////
void debugA( String s ) {
  println("("+lineIdx+", "+lineChar+") --> ("+rowIdx+", "+colIdx+"): "+s);
}
