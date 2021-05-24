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

Johannes Burström 202
*/

#include <Bela.h>
#include <libpd/z_libpd.h>
extern "C" {
#include <libpd/s_stuff.h>
};
#include "Bela_BNO055.h"

class Pd_BNO055 {
	public: 
		Pd_BNO055() {};
		bool setup(BelaContext *context);
		void render(BelaContext *context);
		void doCalibrationStep();
		void loadCalibration(float w, float x, float y, float z);
		static void getNeutralGravityStatic(void* arg); 
		static void getDownGravityStatic(void* arg); 
		static void readIMUStatic(void* arg); 

	private:
		// Change this to change how often the BNO055 IMU is read (in Hz)
		int readInterval = 100;
		I2C_BNO055 bno; // IMU sensor object

		// Quaternions and Vectors
		imu::Quaternion gCal, gCalLeft, gCalRight, gIdleConj = {1, 0, 0, 0};
		imu::Quaternion qGravIdle, qGravCal, quat, steering, qRaw;

		imu::Vector<3> gRaw;         
		imu::Vector<3> gGravIdle, gGravCal;
		imu::Vector<3> ypr; //yaw pitch and roll angles

		bool doCalibration  = false;
		int calibrationState = 0; // state machine variable for calibration
		int setForward = 0; // flag for setting forward orientation

		// variables handling threading
		AuxiliaryTask i2cTask;		// Auxiliary task to read I2C
		AuxiliaryTask gravityNeutralTask;		// Auxiliary task to read gravity from I2C
		AuxiliaryTask gravityDownTask;		// Auxiliary task to read gravity from I2C

		int readCount = 0;			// How long until we read again...
		int readIntervalSamples = 0; // How many samples between reads

		//int printThrottle = 0; // used to limit printing frequency

		// function declarations
		void readIMU();
		void getNeutralGravity();
		void getDownGravity();
		void calibrate();
		void resetOrientation();
};




