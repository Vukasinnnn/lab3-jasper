/*****************************************************************************

 (c) Copyright 2004, Cadence Design Systems, Inc.                       
 All rights reserved.                                                   

 This software is the proprietary information of Cadence Design         
 Systems, Inc. and may not be copied or reproduced in whole or in part  
 onto any medium without Cadence's express prior written consent.       

 This software is provided to the end user solely for his/her use.  No  
 warranties are expressed or implied herein including those as to       
 merchantability and fitness for a particular purpose.  In no event     
 shall Cadence be held liable for loss of profit, business              
 interruption, data, loss of information, or any other pecuniary loss   
 including but not limited to special, incidental, consequential, or    
 other damages.                                                         

 Author: Paul Hylander

******************************************************************************/


`define dfafn_range2size(n)	((n) <= (1<<0) ? 1 : (n) <= (1<<1) ? 1 :\
			 (n) <= (1<<2) ? 2 : (n) <= (1<<3) ? 3 :\
			 (n) <= (1<<4) ? 4 : (n) <= (1<<5) ? 5 :\
			 (n) <= (1<<6) ? 6 : (n) <= (1<<7) ? 7 :\
			 (n) <= (1<<8) ? 8 : (n) <= (1<<9) ? 9 :\
			 (n) <= (1<<10) ? 10 : (n) <= (1<<11) ? 11 :\
			 (n) <= (1<<12) ? 12 : (n) <= (1<<13) ? 13 :\
			 (n) <= (1<<14) ? 14 : (n) <= (1<<15) ? 15 :\
			 (n) <= (1<<16) ? 16 : (n) <= (1<<17) ? 17 :\
			 (n) <= (1<<18) ? 18 : (n) <= (1<<19) ? 19 :\
			 (n) <= (1<<20) ? 20 : (n) <= (1<<21) ? 21 :\
			 (n) <= (1<<22) ? 22 : (n) <= (1<<23) ? 23 :\
			 (n) <= (1<<24) ? 24 : (n) <= (1<<25) ? 25 :\
			 (n) <= (1<<26) ? 26 : (n) <= (1<<27) ? 27 :\
			 (n) <= (1<<28) ? 28 : (n) <= (1<<29) ? 29 :\
			 (n) <= (1<<30) ? 30 : (n) <= (1<<31) ? 31 : 32)

`define dfafn_clogb2(n)	((n) <= (1<<0) ? 0 : (n) <= (1<<1) ? 1 :\
			 (n) <= (1<<2) ? 2 : (n) <= (1<<3) ? 3 :\
			 (n) <= (1<<4) ? 4 : (n) <= (1<<5) ? 5 :\
			 (n) <= (1<<6) ? 6 : (n) <= (1<<7) ? 7 :\
			 (n) <= (1<<8) ? 8 : (n) <= (1<<9) ? 9 :\
			 (n) <= (1<<10) ? 10 : (n) <= (1<<11) ? 11 :\
			 (n) <= (1<<12) ? 12 : (n) <= (1<<13) ? 13 :\
			 (n) <= (1<<14) ? 14 : (n) <= (1<<15) ? 15 :\
			 (n) <= (1<<16) ? 16 : (n) <= (1<<17) ? 17 :\
			 (n) <= (1<<18) ? 18 : (n) <= (1<<19) ? 19 :\
			 (n) <= (1<<20) ? 20 : (n) <= (1<<21) ? 21 :\
			 (n) <= (1<<22) ? 22 : (n) <= (1<<23) ? 23 :\
			 (n) <= (1<<24) ? 24 : (n) <= (1<<25) ? 25 :\
			 (n) <= (1<<26) ? 26 : (n) <= (1<<27) ? 27 :\
			 (n) <= (1<<28) ? 28 : (n) <= (1<<29) ? 29 :\
			 (n) <= (1<<30) ? 30 : (n) <= (1<<31) ? 31 : 32)

`define dfafn_flogb2(n)	((n) < (1<<1) ? 0 : (n) < (1<<2) ? 1 :\
			 (n) < (1<<3) ? 2 : (n) < (1<<4) ? 3 :\
			 (n) < (1<<5) ? 4 : (n) < (1<<6) ? 5 :\
			 (n) < (1<<7) ? 6 : (n) < (1<<8) ? 7 :\
			 (n) < (1<<9) ? 8 : (n) < (1<<10) ? 9 :\
			 (n) < (1<<11) ? 10 : (n) < (1<<12) ? 11 :\
			 (n) < (1<<13) ? 12 : (n) < (1<<14) ? 13 :\
			 (n) < (1<<15) ? 14 : (n) < (1<<16) ? 15 :\
			 (n) < (1<<17) ? 16 : (n) < (1<<18) ? 17 :\
			 (n) < (1<<19) ? 18 : (n) < (1<<20) ? 19 :\
			 (n) < (1<<21) ? 20 : (n) < (1<<22) ? 21 :\
			 (n) < (1<<23) ? 22 : (n) < (1<<24) ? 23 :\
			 (n) < (1<<25) ? 24 : (n) < (1<<26) ? 25 :\
			 (n) < (1<<27) ? 26 : (n) < (1<<28) ? 27 :\
			 (n) < (1<<29) ? 28 : (n) < (1<<30) ? 29 :\
			 (n) < (1<<31) ? 30 : (n) == (1<<32) ? 32 : 31)

`define dfafn_pow2(n)	(1 << (n))

`define dfafn_max3(n,m,o)  ((n) >= (m) && (n) >= (o) ? (n) :\
			    (m) >= (n) && (m) >= (o) ? (m) :\
			    (o))

`define dfafn_cdiv(a,b) (((a)+(b)-1)/(b))

//function integer dfafn_range2size(input integer num);
//	integer tmp, res;
//begin
//	tmp=num-1;
//	for (res=0; tmp>0; res=res+1)
//        	tmp=tmp>>1;
//	if (res == 0) res=1;
//	dfafn_range2size = res;
//end
//endfunction
//
//function integer dfafn_clogb2(input integer num);
//	integer tmp, res;
//begin
//	tmp=num-1;
//	for (res=0; tmp>0; res=res+1)
//        	tmp=tmp>>1;
//	dfafn_clogb2 = res;
//end
//endfunction
//
//function integer dfafn_flogb2(input integer num);
//        integer tmp, res;
//begin
//	tmp=num;
//	tmp=tmp>>1;
//	for (res=0; tmp>0; res=res+1)
//		tmp=tmp>>1;
//	dfafn_flogb2 = res;
//end
//endfunction
//
