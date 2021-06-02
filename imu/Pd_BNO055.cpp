/*
Inertial Measurement Unit (IMU) Sensing with the BNO055
----------------------------------------------------------

This sketch allows you to hook up BNO055 IMU movement sensing device
to Bela, for example the Adafruit BNO055 breakout board.

To get this working with Bela you need to connect the breakout board to the I2C
terminal on the Bela board. See the Pin guide for details of which pin is which.

Connect a push button with a pull-down resistor to pin P8_08.

When running sketch, hold IMU in a neutral position and press the push button 
once. Tilt IMU down (if wearing as for head-tracking, look down) and press the 
push button a second time. The system is now calibrated. Calibration can be
run again at any time.

Based on IMU-Sine-Synth-Pd Example from Bela On Ur Head by Becky Stewart
https://github.com/theleadingzero/belaonurhead

Johannes Burström 2021
*/

#include "Pd_BNO055.h"

bool Pd_BNO055::setup(BelaContext *context) {
	if(!bno.begin()) {
		rt_printf("Error initialising BNO055\n");
		return false;
	}
	
	rt_printf("Initialised BNO055\n");
	
	// use external crystal for better accuracy
  	bno.setExtCrystalUse(true);
  	
	// get the system status of the sensor to make sure everything is ok
	uint8_t sysStatus, selfTest, sysError;
  	bno.getSystemStatus(&sysStatus, &selfTest, &sysError);
	rt_printf("System Status: %d (0 is Idle)   Self Test: %d (15 is all good)   System Error: %d (0 is no error)\n", sysStatus, selfTest, sysError);

	
	// set sensor reading in a separate thread
	// so it doesn't interfere with the audio processing
	i2cTask = Bela_createAuxiliaryTask(Pd_BNO055::readIMUStatic, 5, "bela-bno", (void*)this);
	readIntervalSamples = context->audioSampleRate / readInterval;
	
	gravityNeutralTask = Bela_createAuxiliaryTask(Pd_BNO055::getNeutralGravityStatic, 5, "bela-neu-gravity", (void*)this);
	gravityDownTask = Bela_createAuxiliaryTask(Pd_BNO055::getDownGravityStatic, 5, "bela-down-gravity", (void*)this);
	
	// set up button pin
	//pinMode(context, 0, buttonPin, INPUT); 
	
	return true;
}

void Pd_BNO055::render(BelaContext *context) {
	//************ Added for BNO055 based head-tracking ***************

	// this schedules the imu sensor readings
	if(++readCount >= readIntervalSamples) {
		readCount = 0;
		Bela_scheduleAuxiliaryTask(i2cTask);
        // send IMU values to Pd
        libpd_float("bno_yaw", ypr[0]);
        libpd_float("bno_pitch", ypr[1]);
        libpd_float("bno_roll", ypr[2]);
	}


	if( doCalibration ){
		// then run calibration to set looking forward (gGravIdle) 
		// and looking down (gGravCal)
		switch(calibrationState) {
			case 0: // first time button was pressed
				rt_printf("Calibration step 1\n");
				setForward = 1;
				// run task to get gravity values when sensor in neutral position
				Bela_scheduleAuxiliaryTask(gravityNeutralTask);
				calibrationState = 1;	// progress calibration state
				break;
			case 1: // second time button was pressed
				// run task to get gravity values when sensor 'looking down' (for head-tracking) 
				rt_printf("Calibration step 2\n");
				Bela_scheduleAuxiliaryTask(gravityDownTask);
				calibrationState = 0; // reset calibration state for next time
				break;
		} 
		doCalibration = false;
	}

}

void Pd_BNO055::doCalibrationStep()
{
	doCalibration = true;
}

void Pd_BNO055::loadCalibration(float w, float x, float y, float z)
{
	gCal = imu::Quaternion(w, x, y, z);
	resetOrientation();
}

// Auxiliary task to read from the I2C board
void Pd_BNO055::readIMU()
{
	// get calibration status
	uint8_t sys, gyro, accel, mag;
	bno.getCalibration(&sys, &gyro, &accel, &mag);
	// status of 3 means fully calibrated
	//rt_printf("CALIBRATION STATUSES\n");
	//rt_printf("System: %d   Gyro: %d Accel: %d  Mag: %d\n", sys, gyro, accel, mag);
	
	// quaternion data routine from MrHeadTracker
  	imu::Quaternion qRaw = bno.getQuat(); //get sensor raw quaternion data
  	
  	if( setForward ) {
  		gIdleConj = qRaw.conjugate(); // sets what is looking forward
  		setForward = 0; // reset flag so only happens once
  	}
		
  	steering = gIdleConj * qRaw; // calculate relative rotation data
  	quat = gCalLeft * steering; // transform it to calibrated coordinate system
  	quat = quat * gCalRight;

  	ypr = quat.toEuler(); // transform from quaternion to Euler
}

void Pd_BNO055::readIMUStatic(void* arg) {
	Pd_BNO055* that = (Pd_BNO055*)arg;
	that->readIMU();
}

// Auxiliary task to read from the I2C board
void Pd_BNO055::getNeutralGravity() {
	// read in gravity value
  	imu::Vector<3> gravity = bno.getVector(I2C_BNO055::VECTOR_GRAVITY);
  	gravity = gravity.scale(-1);
  	gravity.normalize();
  	gGravIdle = gravity;
}

void Pd_BNO055::getNeutralGravityStatic(void* arg) {
	Pd_BNO055* that = (Pd_BNO055*)arg;
	that->getNeutralGravity();
}

// Auxiliary task to read from the I2C board
void Pd_BNO055::getDownGravity() {
	// read in gravity value
  	imu::Vector<3> gravity = bno.getVector(I2C_BNO055::VECTOR_GRAVITY);
  	gravity = gravity.scale(-1);
  	gravity.normalize();
  	gGravCal = gravity;
  	// run calibration routine as we should have both gravity values
  	calibrate(); 
}

void Pd_BNO055::getDownGravityStatic(void* arg) {
	Pd_BNO055* that = (Pd_BNO055*)arg;
	that->getDownGravity();
}

// calibration of coordinate system from MrHeadTracker
// see http://www.aes.org/e-lib/browse.cfm?elib=18567 for full paper
// describing algorithm
void Pd_BNO055::calibrate() {
  	imu::Vector<3> g, gravCalTemp, x, y, z;
  	g = gGravIdle; // looking forward in neutral position
  
  	z = g.scale(-1); 
  	z.normalize();

  	gravCalTemp = gGravCal; // looking down
  	y = gravCalTemp.cross(g);
  	y.normalize();

  	x = y.cross(z);
  	x.normalize();

  	imu::Matrix<3> rot;
  	rot.cell(0, 0) = x.x();
  	rot.cell(1, 0) = x.y();
  	rot.cell(2, 0) = x.z();
  	rot.cell(0, 1) = y.x();
  	rot.cell(1, 1) = y.y();
  	rot.cell(2, 1) = y.z();
  	rot.cell(0, 2) = z.x();
  	rot.cell(1, 2) = z.y();
  	rot.cell(2, 2) = z.z();

  	gCal.fromMatrix(rot);

	libpd_start_message(4);
	libpd_add_float(gCal.w());
	libpd_add_float(gCal.x());
	libpd_add_float(gCal.y());
	libpd_add_float(gCal.z());
	libpd_finish_list("bno_calibrated");

  	resetOrientation();
}

// from MrHeadTracker
// resets values used for looking forward
void Pd_BNO055::resetOrientation() {
  	gCalLeft = gCal.conjugate();
  	gCalRight = gCal;
}


