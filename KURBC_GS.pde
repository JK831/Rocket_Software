import processing.serial.*;

Serial port1 = null; // 시리얼 포트
Serial port2 = null;
Serial port3 = null;
boolean allConnected = true;

float roll, pitch, yaw; // 로켓의 회전 값 저장 위한 변수
float accX, accY, accZ; // 로켓의 축 별 가속도 값
float gyroX, gyroY, gyroZ; // 로켓의 자이로 값

int errorMessagePosX; // 경고 메시지 위치
int errorMessagePosY;

// 메시지, 메시지 박스
byte messageNum = 5;
byte messageTextSize = 12;
byte messageInterval = 5;
String[] messages;
int messageBoxX; // 메시지 박스의 '센터' 좌표
int messageBoxY; // "
int messageX;
int messageY;
int messageBoxWidth;
int messageBoxHeight;
byte messageBoxStrokeWeight;


int graphWidth;
int graphHeight = 120;
int graphInterval = 4;
int graphStartPosX = 0;
int graphStartPosY = 0;

int vectorGraphExtension = 120;
int vectorGraphInterval = 20;
int vectorLength = 50;

float[] roll_vals;
float[] pitch_vals;
float[] latitude_vals;
float[] longitude_vals;
float[] curHeight_vals;
float[] accX_vals;
float[] accY_vals;
float[] accZ_vals;

PImage mapImage; // 맵 이미지를 담을 변수
PShape rocket1; // 로켓 3D 오브젝트
PShape rocket2; // X, Y 따로 출력하기 위해 두 개 선언
PFont font; // 폰트

// 맵 이미지 크기, 맵 받아올 default url, API key
int mapSize = 300;
String url = "https://maps.googleapis.com/maps/api/staticmap?";
String zoomAndSize = "&zoom=17&size=300x300";
String markers = "&markers=color:blue%7Clabel:L%7C";
String APIKey = ""; // API 키 삽입 (Private)

// 경도, 위도 (default = 서울)
float latitude = 37.566535;
float longitude = 126.97796919;

// 고도
float altitude = 0;

// draw() 시작 시점의 시간, 측정시작 시간(ms), 맵 데이터 받아온 마지막 시간
int curTime = 0;
int startTime = -1;
int lastGot = 0;

// 측정 시작 후 경과시간
int elapsedTime = 0;

// 로켓 시간
boolean sendTime = false;
int rocketHour = 0;
int rocketMin = 0;
int rocketSec = 0;

// 발사 시작 버튼
boolean launchButtonOver = false;
int launchButtonX = 0;
int launchButtonY = 0;

// 낙하산 사출 여부
boolean launched = false;

// 낙하산 사출 버튼
boolean parachuteButtonOver = false;
int parachuteButtonX = 0;
int parachuteButtonY = 0;

int circleButtonRadius = 80;
color buttonColor, buttonHighlightColor;

// 로켓 위치 산출 버튼
boolean mapButtonOver = false;
int mapButtonX = 0;
int mapButtonY = 0;

// 로켓 위치 산출 쿨타임 계산을 위한 변수
float coolTime = 3000; // (ms)
float timeToEnable = 0;



public void setup()
{
  fullScreen(P3D);

  try
  {
    port1 = new Serial(this, Serial.list()[0], 115200);
    port1.clear();
  }
  catch (Exception e)
  {
    e.printStackTrace();
    println("Port1, 2, 3 Unconnected");
    allConnected = false;
  }
  try
  {
    port2 = new Serial(this, Serial.list()[1], 115200);
    port2.clear();
  }
  catch (Exception e)
  {
    e.printStackTrace();
    println("Port2, 3 Unconnected");
    //allConnected = false;
  }
  try
  {
    port3 = new Serial(this, Serial.list()[2], 115200);
    port3.clear();
  }
  catch (Exception e)
  {
    e.printStackTrace();
    println("Port3 Unconnected");
    //allConnected = false;
  }

  font = createFont("나눔고딕코딩", 20);
  textFont(font);

  errorMessagePosX = width / 2;
  errorMessagePosY = height / 2;

  buttonColor = color(255);
  buttonHighlightColor = color(204);

  launchButtonX = width / 4 * 3;
  launchButtonY = circleButtonRadius;

  parachuteButtonX = launchButtonX + 10 + circleButtonRadius * 2;
  parachuteButtonY = circleButtonRadius;

  mapButtonX = parachuteButtonX + 10 + circleButtonRadius * 2;
  mapButtonY = circleButtonRadius;

  messages = new String[messageNum];
  messageBoxX = width / 2;
  messageBoxY = 160;
  messageBoxWidth = width / 3;
  messageBoxHeight = (messageTextSize + 2) * messageNum + messageBoxStrokeWeight * 2 + messageInterval * (messageNum + 1);
  messageX = messageBoxX - messageBoxWidth / 2 + messageBoxStrokeWeight;
  messageY = messageBoxY - messageBoxHeight / 2 + messageBoxStrokeWeight;

  graphWidth = width / 4;
  graphStartPosY = height / 4;

  roll_vals = new float[graphWidth];
  pitch_vals = new float[graphWidth];
  latitude_vals = new float[graphWidth];
  longitude_vals = new float[graphWidth];
  curHeight_vals = new float[graphWidth];

  mapImage = loadImage("지도.png");

  rocket1 = loadShape("D:/Rocket/Model_Rocket_with_Narrow_Top_v1_L1/18499_Model_Rocket_with_Narrow_Top_v1_NEW.obj");
  rocket1.scale(2);
  rocket1.rotateX(-PI / 2);

  rocket2 = loadShape("D:/Rocket/Model_Rocket_with_Narrow_Top_v1_L1/18499_Model_Rocket_with_Narrow_Top_v1_NEW.obj");
  rocket2.scale(2);
  rocket2.rotateX(-PI / 2);
}

public void draw()
{
  if (allConnected)
  {
    curTime = millis();
    background(0);
    lights();

    //    | 측정 시작 여부에 따른 로직, 마우스 로직 등 처리
    update();

    //     | 상태표시창 |
    drawStatusUI();

    //     | 로켓 발사(측정 시작) 버튼, 낙하산 사출 버튼, 로켓 위치 산출 버튼
    checkButton();
    
    //    | 아두이노 메시지 박스 |
    showMessagesFromArduino();

    // 실시간 그래프
    drawGraph();

    // 로켓 위치 시각화 (구글 맵)
    drawMap();

    // 방향 벡터
    drawVector();

    //     | 로켓 이미지 출력 |
    mediate3DRocket();
  } else
  {
    allConnected = tryConnect();
  }
}

// 시리얼 통신 연결 시도
boolean tryConnect()
{
  if (port1 == null)
  {
    if (port1 == null)
    {
      try
      {
        port1 = new Serial(this, Serial.list()[0], 115200);
        port1.clear();
      }
      catch (Exception e)
      {
        e.printStackTrace();

        fill(255);
        textSize(50);
        textAlign(CENTER);
        text("보드를 연결하세요", errorMessagePosX, errorMessagePosY);
        return false;
      }
    }
    /*
    if (port2 == null)
    {
      try
      {
        port2 = new Serial(this, Serial.list()[1], 115200);
        port2.clear();
      }
      catch (Exception e)
      {
        e.printStackTrace();

        fill(255);
        textSize(50);
        textAlign(CENTER);
        text("센서2, 3을 연결하세요", errorMessagePosX, errorMessagePosY);
        return false;
      }
    }
    else if (port3 == null)
    {
      try
      {
        port3 = new Serial(this, Serial.list()[2], 115200);
        port3.clear();
      }
      catch (Exception e)
      {
        e.printStackTrace();

        fill(255);
        textSize(50);
        textAlign(CENTER);
        text("센서3을 연결하세요", errorMessagePosX, errorMessagePosY);
        return false;
      }
    }
    */
  }
  return true;
}

// 매 프레임마다 체크해야하는 것들 모아둔 함수
void update()
{
  // 측정 시작 여부에 따른 로직
  if (startTime != -1)
  {
    elapsedTime = millis() - startTime;
  }


  // 마우스 인식 로직
  if ( overCircle(launchButtonX, launchButtonY, circleButtonRadius) )
  {
    launchButtonOver = true;

    parachuteButtonOver = false;
    mapButtonOver = false;
  } else if ( overCircle(parachuteButtonX, parachuteButtonY, circleButtonRadius) )
  {
    parachuteButtonOver = true;

    launchButtonOver = false;
    mapButtonOver = false;
  } else if ( overCircle(mapButtonX, mapButtonY, circleButtonRadius) )
  {
    mapButtonOver = true;

    launchButtonOver = false;
    parachuteButtonOver = false;
  } else
    launchButtonOver = parachuteButtonOver = mapButtonOver = false;
}

void drawStatusUI()
{
  pushMatrix();
  translate(20, 20);
  fill(255);
  textSize(20);
  textAlign(LEFT);
  text("현재 날짜 및 시각(PC): " + year() + "년" + month() + "월" + day() + "일" + hour() + "시" + minute() + "분" + second() + "초", 0, 0);

  translate(0, 30);
  text("현재 시각(로켓): " + rocketHour + ":" + rocketMin + ":" + rocketSec, 0, 0);

  translate(0, 30);
  text("측정 후 경과시간(ms): " + elapsedTime, 0, 0);


  popMatrix(); // 상태표시창 End
}

// 버튼 동작을 위한 함수
void checkButton()
{
  if (launchButtonOver)
  {
    fill(buttonHighlightColor);
  } else
    fill(buttonColor);
  stroke(0);
  ellipse(launchButtonX, launchButtonY, circleButtonRadius * 2, circleButtonRadius * 2);
  fill(0);
  textSize(20);
  textAlign(CENTER);
  text("측정 시작", launchButtonX, launchButtonY);


  if (parachuteButtonOver)
  {
    fill(buttonHighlightColor);
  } else
    fill(buttonColor);
  stroke(0);
  ellipse(parachuteButtonX, parachuteButtonY, circleButtonRadius * 2, circleButtonRadius * 2);
  fill(0);
  textSize(20);
  textAlign(CENTER);
  text("낙하산 사출", parachuteButtonX, parachuteButtonY);


  if (curTime < timeToEnable)
  {

    fill(buttonHighlightColor);
    stroke(0);
    ellipse(mapButtonX, mapButtonY, circleButtonRadius * 2, circleButtonRadius * 2);

    float curRadius = circleButtonRadius * (curTime - lastGot) / coolTime;
    fill(buttonColor);
    stroke(0);
    ellipse(mapButtonX, mapButtonY, curRadius * 2, curRadius * 2);
    fill(255, 0, 0);
    textSize(20);
    textAlign(CENTER);
    text("쿨타임", mapButtonX, mapButtonY);
  }
  else
  {
    if (mapButtonOver)
    {
      fill(buttonHighlightColor);
    } else
      fill(buttonColor);
    stroke(0);
    ellipse(mapButtonX, mapButtonY, circleButtonRadius * 2, circleButtonRadius * 2);
    fill(0);
    textSize(20);
    textAlign(CENTER);
    text("위치 산출\n쿨타임 3초", mapButtonX, mapButtonY);
  }
}

void drawGraph()
{
  pushMatrix();

  translate(graphStartPosX + 20, graphStartPosY + graphHeight);
  stroke(255);
  strokeWeight(3);
  noFill();
  rectMode(CORNER);
  rect(-3, -graphHeight * 2, graphWidth + 3, graphHeight * 2 -20); // 그래프 범위 나타낼 사각형
  fill(255);
  textSize(20);
  textAlign(LEFT);
  text("90", graphWidth, -graphHeight * 2); // 자이로 센서로 계산한 각도 수치(-90~90도)
  text("0", graphWidth + 5, -graphHeight);
  text("-90", graphWidth, 0);
  text("MPU X", 0, 0);
  stroke(255, 0, 0);
  strokeWeight(2);
  line(60, -5, 80, -5);
  text("MPU Y", 90, 0);
  stroke(0, 255, 0);
  line(150, -5, 170, -5);


  if (elapsedTime != 0) // 측정이 시작됐을 시
  {
    translate(0, -graphHeight);
    for (int i = 0; i < graphWidth - 1; i++)
      roll_vals[i] = roll_vals[i + 1];
    roll_vals[graphWidth - 1] = roll;
    stroke(255, 0, 0);     //stroke color
    strokeWeight(2);
    for (int x = 0; x < graphWidth - 1; x++)
    {
      line (x, -roll_vals[x], x + 1, -roll_vals[x + 1]);
    }

    translate(0, graphInterval);
    for (int i = 0; i < graphWidth - 1; i++)
      pitch_vals[i] = pitch_vals[i + 1];
    pitch_vals[graphWidth - 1] = pitch;
    stroke(0, 255, 0);     //stroke color
    strokeWeight(2);
    for (int x = 0; x < graphWidth - 1; x++)
    {
      line (x, -pitch_vals[x], x + 1, -pitch_vals[x + 1]);
    }
  }
  popMatrix();
}

void showMessagesFromArduino()
{
  stroke(255);
  strokeWeight(2);
  noFill();
  rectMode(CENTER);
  rect(messageBoxX, messageBoxY, messageBoxWidth, messageBoxHeight);
  textAlign(LEFT, TOP);
  for (int i = 0; i < messageNum; i++)
  {
    if (messages[i] != null)
    {
      
      if (messages[i].contains("Alert"))
        fill(255, 0, 0);
      else
        fill(255);
      text(messages[i], messageX, messageY + (messageTextSize + messageInterval) * i);
    }
  }
}

void drawMap()
{
  pushMatrix();
  translate(width / 8, height / 5 * 3);
  fill(0);
  image(mapImage, -mapSize / 2, - mapSize / 2, 300, 300); // 맵 이미지 출력
  fill(255);
  textSize(20);
  textAlign(CENTER);
  text("로켓 위치(구글 맵)", 0, mapSize / 2 + 20);
  popMatrix();
}

void drawVector()
{
  pushMatrix();
  translate(width / 2, height / 4 * 3);
  rotateY(-PI / 4);

  stroke(255);
  strokeWeight(0.5);
  for (int i = 0; i < vectorGraphExtension / vectorGraphInterval; i++)
  {
    line (0, i * vectorGraphInterval, 0, vectorGraphExtension, i * vectorGraphInterval, 0);
    line (0, i * vectorGraphInterval, 0, 0, i * vectorGraphInterval, vectorGraphExtension);
    line (i * vectorGraphInterval, 0, 0, i * vectorGraphInterval, vectorGraphExtension, 0);
    line (i * vectorGraphInterval, vectorGraphExtension, 0, i * vectorGraphInterval, vectorGraphExtension, vectorGraphExtension);
    line (0, vectorGraphExtension, i * vectorGraphInterval, vectorGraphExtension, vectorGraphExtension, i * vectorGraphInterval);
    line (0, 0, i * vectorGraphInterval, 0, vectorGraphExtension, i * vectorGraphInterval);
  }
  textSize(20);
  textAlign(LEFT);
  fill(255);

  pushMatrix();
  translate(0, vectorGraphExtension, vectorGraphExtension + 20);
  rotateX(PI / 2);
  text("X axis", 0, 0, 0);
  popMatrix();

  pushMatrix();
  translate(vectorGraphExtension + 10, 0, 0);
  //rotateZ(PI / 2);
  text("Y axis", 0, 0, 0);
  popMatrix();

  pushMatrix();
  translate(vectorGraphExtension + 10, vectorGraphExtension + 10, vectorGraphExtension / 2);
  rotateX(PI / 2);
  rotateZ(-PI / 2);
  text("Z axis", 0, 0, 0);
  popMatrix();

  translate(vectorGraphExtension / 2, vectorGraphExtension / 2, vectorGraphExtension / 2);
  rotateX(-radians(roll));
  rotateZ(radians(pitch));
  stroke(255, 0, 0);
  strokeWeight(3);
  line (0, 0, 0, 0, -vectorLength, 0);
  line (0, -vectorLength, 0, vectorLength / 5, -vectorLength / 5 * 4, 0);
  line (0, -vectorLength, 0, -vectorLength / 5, -vectorLength / 5 * 4, 0);
  popMatrix();
}

void mediate3DRocket()
{
  pushMatrix();
  translate(width / 4 * 3, height / 4 * 3);
  fill(255);
  textSize(30);
  textAlign(CENTER);
  text("MPU X", 0, 100);
  text(roll, 0, 130);
  text("MPU Y", 120, 100);
  text(pitch, 120, 130);
  // 측정 시작했다면
  if (elapsedTime != 0)
  {

    println(roll, pitch, yaw);
    pushMatrix();
    rotateX(-radians(roll));
    shape(rocket1);
    popMatrix();
    translate(120, 0);
    rotateZ(radians(pitch));
    shape(rocket2);
  }
  else
  {
    //rotateZ(PI);
    //rotateY(ry);
    shape(rocket1);
    translate(120, 0);
    shape(rocket2);
  }
  popMatrix();
}


boolean overCircle(int x, int y, int diameter)
{
  float disX = x - mouseX;
  float disY = y - mouseY;

  if (sqrt(sq(disX) + sq(disY)) < diameter )
    return true;

  return false;
}

void serialEvent(Serial port)
{
  if (port == port1)
  {
    String str = port1.readStringUntil('\n');
    //rotateZ(PI);
    //rotateY(ry);
    if (str != null)
    {
      if (str.startsWith("Notice") || str.startsWith("Alert"))
      {
        println(str);
        // 아두이노로부터 어떤 메시지를 받았는지 보여줄 수 있도록 저장
        for (int i = 0; i < messageNum - 1; i++)
          messages[i] = messages[i + 1];
   
        messages[messageNum - 1] = hour() + ":" + minute() + ":" + second() + " " + str;
        /* // serialEvents 내에서 그려주는 코드 삽입하면 오류 발생
        if (str.startsWith("Alert"))
        {
          rectMode(CENTER);
          fill(255);
          rect(width / 2, height / 2, width, height / 4);

          fill(255, 127, 0);
          text(str, width / 2, height / 2);
          textSize(24);
          textAlign(CENTER);
          delay(1500);
        }
        */
      }
      else
      {
        String[] times = str.split(":");
        String[] gyroStrs = str.split("\t");
        String[] gpsStrs = str.split(" ");

        if (times.length >= 3)
        {
          rocketHour = PApplet.parseInt(times[0]);
          rocketMin = PApplet.parseInt(times[1]);
          rocketSec = PApplet.parseInt(times[2].trim());
          println(rocketHour, rocketMin, rocketSec);
        }

        else if (gyroStrs.length >= 9)
        {
          accX = PApplet.parseFloat(gyroStrs[0]);
          accY = PApplet.parseFloat(gyroStrs[1]);
          accZ = PApplet.parseFloat(gyroStrs[2]);

          gyroX = PApplet.parseFloat(gyroStrs[3]);
          gyroY = PApplet.parseFloat(gyroStrs[4]);
          gyroZ = PApplet.parseFloat(gyroStrs[5]);

          roll = PApplet.parseFloat(gyroStrs[6]);
          pitch = PApplet.parseFloat(gyroStrs[7]);
          yaw = PApplet.parseFloat(gyroStrs[8].trim());
        }
        else if (gpsStrs.length >= 2)
        {
          latitude = PApplet.parseFloat(gpsStrs[0]);
          longitude = PApplet.parseFloat(gpsStrs[1].trim());
        }

        println(roll, pitch, yaw);
        //roll = roll > 0 ? roll : roll + TWO_PI;
      }

    }
  }

  if (port == port2) // 고도계 센서에서 시리얼 값을 받아왔다면
  {
    String str = port2.readStringUntil('\n');
    altitude = PApplet.parseFloat(str.trim());
  }
}

void mousePressed()
{
  if (launchButtonOver && startTime == -1)
  {
    startTime = millis();
    String time = hour() + ":" + minute() + ":" + second() + "\n";
    println(time);
    port1.write(time);
  }
  if (parachuteButtonOver && launched)
  {
    launched = true;
  }
  if (mapButtonOver && millis() - lastGot + coolTime >= timeToEnable)
  {
    lastGot = millis();
    timeToEnable = lastGot + coolTime;
    String curLatitude = Float.toString(latitude);
    String curLongitude = Float.toString(longitude);
    mapImage = loadImage(url + zoomAndSize + markers + curLatitude + "," + curLongitude +  APIKey, "png");
  }
}
