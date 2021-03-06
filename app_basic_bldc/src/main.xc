/**
 * Module:  app_basic_bldc
 * Version: 1v1
 * Build:
 * File:    main.xc
 * Author: 	L & T
 *
 * The copyrights, all other intellectual and industrial 
 * property rights are retained by XMOS and/or its licensors. 
 * Terms and conditions covering the use of this code can
 * be found in the Xmos End User License Agreement.
 *
 * Copyright XMOS Ltd 2011
 *
 * In the case where this code is a modification of existing code
 * under a separate license, the separate license terms are shown
 * below. The modifications to the code are still covered by the 
 * copyright notice above.
 *
 **/

#include <xs1.h>
#include <platform.h>

#include <stdio.h>

#include "dsc_config.h"
#include "hall_input.h"
#include "pwm_cli_simple.h"
#include "pwm_service_simple.h"
#include "run_motor.h"
#include "watchdog.h"
#include "shared_io.h"
#include "speed_cntrl.h"

// CAN control headers
#ifdef USE_CAN
#include "control_comms_can.h"
#endif

// Ethernet control headers
#ifdef USE_ETH
#include "control_comms_eth.h"
#include "xtcp_client.h"
#include "uip_server.h"
#include "ethernet_server.h"
#include "getmac.h"
#endif

#ifdef USE_XSCOPE
#include <xscope.h>
#endif

// Define where everything is
#define INTERFACE_CORE 0
#define MOTOR_CORE 1

/* core with LCD and BUTTON interfaces */
on stdcore[INTERFACE_CORE]: lcd_interface_t lcd_ports = { PORT_SPI_CLK, PORT_SPI_MOSI, PORT_SPI_SS_DISPLAY, PORT_SPI_DSA };
on stdcore[INTERFACE_CORE]: in port p_btns = PORT_BUTTONS;
on stdcore[INTERFACE_CORE]: out port p_leds = PORT_LEDS;

/* motor1 core ports */
on stdcore[MOTOR_CORE]: port in p_hall1 = PORT_M1_HALLSENSOR;
on stdcore[MOTOR_CORE]: buffered out port:32 p_pwm_hi1[3] = {PORT_M1_HI_A, PORT_M1_HI_B, PORT_M1_HI_C};
on stdcore[MOTOR_CORE]: out port p_motor_lo1[3] = {PORT_M1_LO_A, PORT_M1_LO_B, PORT_M1_LO_C};
on stdcore[INTERFACE_CORE]: out port i2c_wd = PORT_WATCHDOG;
on stdcore[MOTOR_CORE]: clock pwm_clk = XS1_CLKBLK_1;

/* motor2 core ports */
on stdcore[MOTOR_CORE]: port in p_hall2 = PORT_M2_HALLSENSOR;
on stdcore[MOTOR_CORE]: buffered out port:32 p_pwm_hi2[3] = {PORT_M2_HI_A, PORT_M2_HI_B, PORT_M2_HI_C};
on stdcore[MOTOR_CORE]: out port p_motor_lo2[3] = {PORT_M2_LO_A, PORT_M2_LO_B, PORT_M2_LO_C};
on stdcore[MOTOR_CORE]: clock pwm_clk2 = XS1_CLKBLK_4;

//CAN and ETH reset port
on stdcore[INTERFACE_CORE] : out port p_shared_rs=PORT_SHARED_RS;

// CAN
#ifdef USE_CAN
on stdcore[INTERFACE_CORE] : clock p_can_clk = XS1_CLKBLK_4;
on stdcore[INTERFACE_CORE] : buffered in port:32 p_can_rx = PORT_CAN_RX;
on stdcore[INTERFACE_CORE] : port p_can_tx = PORT_CAN_TX;
#endif

// OTP for MAC address
#ifdef USE_ETH
on stdcore[INTERFACE_CORE]: port otp_data = XS1_PORT_32A;
on stdcore[INTERFACE_CORE]: out port otp_addr = XS1_PORT_16A;
on stdcore[INTERFACE_CORE]: port otp_ctrl = XS1_PORT_16B;
// Ethernet Ports
on stdcore[INTERFACE_CORE]: clock clk_mii_ref = XS1_CLKBLK_REF;
on stdcore[INTERFACE_CORE]: clock clk_smi = XS1_CLKBLK_3;
on stdcore[INTERFACE_CORE]: smi_interface_t smi = { PORT_ETH_MDIO, PORT_ETH_MDC, 0 };
on stdcore[INTERFACE_CORE]: mii_interface_t mii = { XS1_CLKBLK_1, XS1_CLKBLK_2, PORT_ETH_RXCLK, PORT_ETH_RXER, PORT_ETH_RXD, PORT_ETH_RXDV, PORT_ETH_TXCLK, PORT_ETH_TXEN, PORT_ETH_TXD };
#endif


#ifdef USE_CAN

#include "CanPhy.h"

void init_can_phy( chanend c_rxChan, chanend c_txChan, clock p_can_clk, buffered in port:32 p_can_rx, port p_can_tx, out port p_shared_rs)
{
	p_shared_rs <: 0;

	canPhyRxTx( c_rxChan, c_txChan, p_can_clk, p_can_rx, p_can_tx );
}

#endif

#ifdef USE_ETH

#include "ethernet_server.h"
#include "getmac.h"
#include "uip_server.h"

int mac_address[2];

// Function to initialise and run the TCP/IP server
void init_tcp_server(chanend c_mac_rx, chanend c_mac_tx, chanend c_xtcp[], chanend c_connect_status)
{
#if 0
	xtcp_ipconfig_t ipconfig =
	{
	  {0,0,0,0},		// ip address
	  {0,0,0,0},		// netmask
	  {0,0,0,0}       	// gateway
	};
#else
	xtcp_ipconfig_t ipconfig =
	{
	  {169, 254, 0, 1},	// ip address
	  {255,255,0,0},	// netmask
	  {0,0,0,0}       	// gateway
	};
#endif

	// Start the TCP/IP server
	uip_server(c_mac_rx, c_mac_tx, c_xtcp, 1, ipconfig, c_connect_status);
}


// Function to initialise and run the Ethernet server
void init_ethernet_server( port p_otp_data, out port p_otp_addr, port p_otp_ctrl, clock clk_smi, clock clk_mii, smi_interface_t &p_smi, mii_interface_t &p_mii, chanend c_mac_rx[], chanend c_mac_tx[], chanend c_connect_status, out port p_reset)
{
	// Bring the ethernet PHY out of reset
	p_reset <: 0x2;

	// Get the MAC address
	ethernet_getmac_otp(p_otp_data, p_otp_addr, p_otp_ctrl, (mac_address, char[]));

	// Initiate the PHY
	phy_init(clk_smi, null, p_smi, p_mii);

	// Run the Ethernet server
	ethernet_server(p_mii, mac_address, c_mac_rx, 1, c_mac_tx, 1, p_smi, c_connect_status);
}

#endif



int main ( void )
{
	chan c_wd, c_commands[NUMBER_OF_MOTORS], c_speed[NUMBER_OF_MOTORS], c_control[NUMBER_OF_MOTORS], c_pwm[NUMBER_OF_MOTORS];

#ifdef USE_CAN
	chan c_rxChan, c_txChan;
#endif

#ifdef USE_ETH
	chan c_mac_rx[1], c_mac_tx[1], c_xtcp[1], c_connect_status;
#endif

	par
	{
#ifdef USE_CAN
		on stdcore[INTERFACE_CORE] : do_comms_can( c_commands, c_rxChan, c_txChan);

		on stdcore[INTERFACE_CORE] : init_can_phy( c_rxChan, c_txChan, p_can_clk, p_can_rx, p_can_tx, p_shared_rs );
#endif

#ifdef USE_ETH
		on stdcore[INTERFACE_CORE] : init_tcp_server( c_mac_rx[0], c_mac_tx[0], c_xtcp, c_connect_status );
		on stdcore[MOTOR_CORE] : do_comms_eth( c_commands, c_xtcp[0] );
		on stdcore[INTERFACE_CORE]: init_ethernet_server(otp_data, otp_addr, otp_ctrl, clk_smi, clk_mii_ref, smi, mii, c_mac_rx, c_mac_tx, c_connect_status, p_shared_rs); // +4 threads
#endif

		/* L2 */
		on stdcore[INTERFACE_CORE]: do_wd(c_wd, i2c_wd);

		on stdcore[MOTOR_CORE]: speed_control( c_control[0], c_speed[0], c_commands[0]);
		on stdcore[MOTOR_CORE]: speed_control( c_control[1], c_speed[1], c_commands[1]);

		on stdcore[INTERFACE_CORE]: {
#ifdef USE_XSCOPE
			xscope_register(5,
					XSCOPE_CONTINUOUS, "PWM 1", XSCOPE_UINT , "n",
					XSCOPE_CONTINUOUS, "PWM 2", XSCOPE_UINT , "n",
					XSCOPE_CONTINUOUS, "Speed 1", XSCOPE_UINT , "rpm",
					XSCOPE_CONTINUOUS, "Speed 2", XSCOPE_UINT , "rpm",
					XSCOPE_CONTINUOUS, "Set Speed", XSCOPE_UINT, "rpm"
			);
#endif
			display_shared_io_manager( c_speed, lcd_ports, p_btns, p_leds);
		}

		/* L1 */
		on stdcore[MOTOR_CORE]: do_pwm_simple(c_pwm[0], p_pwm_hi1, pwm_clk);
		on stdcore[MOTOR_CORE]: run_motor(c_pwm[0], c_control[0], p_hall1, p_motor_lo1, c_wd );
		on stdcore[MOTOR_CORE]: do_pwm_simple(c_pwm[1], p_pwm_hi2, pwm_clk2);
		on stdcore[MOTOR_CORE]: run_motor(c_pwm[1], c_control[1], p_hall2, p_motor_lo2, null );


	}
	return 0;
}
