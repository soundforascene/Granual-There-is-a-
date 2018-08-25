// Machine.add(me.dir()+ "/keypress.ck") => int ID;
// HID 
Hid hi; 
HidMsg msg; 

// What keyboard 
0 => int device; 
// Get from command line 
if(me.args() ) me.arg(0) => Std.atoi => device; 

// Open Keybaord ( get deivce number from command line) 
if (!hi.openKeyboard(device) ) me.exit(); 
<<< "Keyboard '" + hi.name() + "' ready", "" >>>;  

SndBuf2 buf => Envelope e => dac;
buf => e => LiSa l[10] => dac;

// Read soundfile 
me.dir() + "/home.wav" => buf.read; 
// Uncoment to make go in reverse

//-0.1 => buf.rate;

// Variables and initial values
80 => float grain_duration;
5.0 => float rand_grain_duration; 
1 => int position;
1.0 => float pitch;
0 => int rand_position; 
0.0 => float rand_pitch;
0.0 => float pause;

// Lisa peramiters
int recording[10];
for(0 => int i; i < 10 ; i++) { 
5::second => l[i].duration; 
200 => l[i].maxVoices;
0 => recording[i];
l[i] => dac;
}


// LiSa Functions

fun void sample(int i)
{ 
	if (recording[i] == 0 ) {
		1 => l[i].record;
		1 => recording[i];
		<<< "Recording in Slot:", i>>>;		
	}
	else if (recording[i] == 1) {
		0 => l[i].record;
		2 => recording[i];
		<<< "Stop Recording in Slot: ", i>>>;
	}
	else if (recording[i] == 2) {
		1 => l[i].play;
		3 => recording[i];
		<<< "Playing Slot:",i >>>;
	}
	else if (recording[i] == 3) {
		0 => recording[i];
		l[i].clear;
		<<< "Slot Reset" >>>;
	}

}

fun void sampleSlots(int i) {
	
	if(msg.which == i) {
		sample(i-30);
	}
}

// targets for ramping
float position_target;
1.0 => float pitch_target;
1.0 => float gain_target => buf.gain; 

// Number of samples in the buffer
int samples;
buf.samples() => samples;
grain_duration*0.5::ms => e.duration; 
 


fun void grain() 
{
	0.0 => float grain_length;
	
	while (true) 
	{
		// Compute grain length
		Std.rand2f( Math.max(1.0, grain_duration - rand_grain_duration), 
					grain_duration + rand_grain_duration) => grain_length;
		// Compute grain duration for envelope
        grain_length*0.5::ms => e.duration;
        // Set buffer playback rate
        Std.rand2f( Math.max(0.0625, pitch-rand_pitch), pitch+rand_pitch ) => buf.rate;
		// Set buffer position
		Std.rand2( Math.max(1, position - rand_position) $ int, 
				   Math.min(samples, position + rand_position) $ int) => buf.pos; 
		
		// Enable envelope 
		e.keyOn(); 
		// Wait for rise
		grain_length*0.5::ms => now; 
		// Close envelope 
		e.keyOff();
		// Wait 
		grain_length*0.5::ms => now; 	
		// Until next grain 
		pause::ms => now; 
	}
}

// Position interpolation
fun void ramp_position()
{
	// Compute rough threshold
	2.0 * (samples) $ float / 10.0 => float thresh;
	// choose slew
	0.005 => float slew;	
	// Go
	while( true )	{
		// Really far away from target?
		if( Std.fabs(position - position_target) > samples / 5 )	{
			1.0 => slew;
		}
		else	{
			0.005 => slew;
		}	
		// Slew towards position
		( (position_target - position) * slew + position ) $ int => position;
		// Wait time
		1::ms => now;
	}
}

// volume interpolation
fun void ramp_gain()	{   
	// the slew
	0.05 => float slew;
	// go
	while( true )	{
		// slew
		( (gain_target - buf.gain()) * slew + buf.gain() ) => buf.gain;
		// wait
		10::ms => now;
	}
}

// spork 
spork ~ grain();
spork ~ ramp_position(); 
spork ~ ramp_gain();

// Set gain  
0.0 => float temp_gain;

while (true)
{		
	hi => now;
	while (hi.recv(msg) != 0 ) 	
	{		
		if(msg.isButtonDown() ) 
		{				
			if( msg.which == 4 ) // A
			{
				Math.min(5000.0, (grain_duration * 1.06)) => grain_duration;
				grain_duration * 0.5::ms => e.duration;
				<<< "Grain Length: ", grain_duration >>>;
			}
			else if( msg.which == 7 ) // D
			{ 
                Math.max(1.0, (grain_duration/1.06)) => grain_duration;                                    
                grain_duration*0.5::ms => e.duration;
                <<< "Grain length: ", grain_duration >>>;
			}
			else if( msg.which == 22 ) // S
			{
				 Math.min(samples, position - 11025) => position_target;
				 <<< "Position: ", position >>>;
			}
			else if(msg.which == 26 ) // W
			{
				Math.max(1, position + 11025) => position_target;
				<<< "Position: ", position >>>;
			}
			
			
			// gain (up arrow)
			else if(msg.which == 82)
			{
				// 0.05 + gain_target => temp_gain;
				if( gain_target <= .05 ) {
					0.05 + gain_target => temp_gain;
				} else {
					gain_target*1.1 => temp_gain;
				}
				
				Math.min( 6.0, temp_gain ) => temp_gain;
				temp_gain => gain_target;
				<<< "Gain: ", buf.gain() >>>;
			}            
			else if(msg.which == 81) // (down arrow)
			{
				// gain_target - 0.05 => temp_gain;
				if( gain_target <= .05 ) {
					0.0 => temp_gain;
				} else {
					gain_target/1.1 => temp_gain;
				}
				
				Math.max( 0.0, temp_gain ) => temp_gain;	
				temp_gain => gain_target;
				<<< "Gain: ", buf.gain() >>>;
			}
			
			// pitch
			else if(msg.which == 80)
			{
				pitch - .05 / 12 => pitch_target => pitch;
				<<< "pitch: ", pitch_target >>>;
			}
			else if(msg.which == 79 )
			{
				pitch + .05 / 12 => pitch_target => pitch;
				<<< "pitch: ", pitch_target >>>;
			}
			
			// LiSa
			int n;
			
			if ((msg.which >= 30) && (msg.which <= 39)) {
				msg.which => n;
		    }
			
            sampleSlots(n);
			 
		}		
	1::ms => now; 			
	}
}