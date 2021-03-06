/**
 * Module:  module_dsc_blocks
 * Version: 1v0alpha1
 * Build:   c9e25ba4f74e9049d5da65cb5c829a3d932ed199
 * File:    pid_regulator.h
 * Modified by : Srikanth
 * Last Modified on : 04-May-2011
 *
 * The copyrights, all other intellectual and industrial 
 * property rights are retained by XMOS and/or its licensors. 
 * Terms and conditions covering the use of this code can
 * be found in the Xmos End User License Agreement.
 *
 * Copyright XMOS Ltd 2010
 *
 * In the case where this code is a modification of existing code
 * under a separate license, the separate license terms are shown
 * below. The modifications to the code are still covered by the 
 * copyright notice above.
 *
 **/

#ifdef __dsc_config_h_exists__
#include <dsc_config.h>
#endif

#ifndef __PI_REGULATOR_H__
#define __PI_REGULATOR_H__

#ifdef BLDC_BASIC
#define PID_RESOLUTION 15
#endif

#ifdef BLDC_FOC
#define PID_RESOLUTION 13
#endif

#ifndef PID_RESOLUTION
#define PID_RESOLUTION 15
#endif

#define PID_MAX_OUTPUT	32768
#define PID_MIN_OUTPUT  -32767

typedef struct S_PID {
	int previous_error;
	int integral;
	int Kp;
	int Ki;
	int Kd;
} pid_data;

#ifdef __XC__
// XC Version
int pid_regulator( int set_point, int actual, pid_data &d );
int pid_regulator_delta( int set_point, int actual, pid_data &d );
int pid_regulator_delta_cust_error( int error, pid_data &d );
int pid_regulator_delta_cust_error_speed( int error, pid_data &d );
int pid_regulator_delta_cust_error_Iq_control( int error, pid_data &iq );
int pid_regulator_delta_cust_error_Id_control( int error, pid_data &id );
void init_pid( int Kp, int Ki, int Kd, pid_data &d );
#else
// C Version
int pid_regulator( int set_point, int actual, pid_data *d );
int pid_regulator_delta( int set_point, int actual, pid_data *d );
int pid_regulator_delta_cust_error( int error, pid_data *d );
int pid_regulator_delta_cust_error_speed( int error, pid_data *d );
int pid_regulator_delta_cust_error_Iq_control( int error, pid_data *iq );
int pid_regulator_delta_cust_error_Id_control( int error, pid_data *id );
void init_pid( int Kp, int Ki, int Kd, pid_data *d );
#endif

#endif
