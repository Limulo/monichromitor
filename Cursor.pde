class Cursor
{
  int x, y;
  int blinkTime;
  int previous;
  boolean bLight = true;
  PImage r;
  
  int fontW;
  int fontH;
  
  Cursor(int _x, int _y, int _fW, int _fH, int _blinkTime) {
    fontW = _fW;
    fontH = _fH;
    x = _x * fontW;
    y = _y * fontH;
    blinkTime = _blinkTime;
    r = createImage(fontW, fontH, RGB);
    r.loadPixels();
    for (int i = 0; i < r.pixels.length; i++) {
      r.pixels[i] = color( MONOCHROME ); 
    }
    r.updatePixels();
    previous = millis();
  }
   
  void move(int _x, int _y) {
    x = _x * fontW;
    y = _y * fontH; 
    bLight = true;
  }
  
  void update(int time) {
    if(time - previous> blinkTime){
      bLight = !bLight;
      previous = time;
    }
  }
 
  void display() {
    if(bLight){
      pushStyle();
      noStroke();
      //fill(0, 255, 0);
      blend(r, 0, 0, fontW, fontH, x, y, fontW, fontH, DIFFERENCE);
      popStyle();
    }
  }
}
