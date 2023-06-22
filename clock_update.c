#include <stdio.h>
#include "clock.h"

int set_tod_from_ports(tod_t *tod){
  // check for invalid TIME_OF_DAY_PORT - 1382400 = 16*24*60*60
  if(TIME_OF_DAY_PORT < 0 || TIME_OF_DAY_PORT > (1382400)){
    return 1;
  }
  // this segment does the rounding
  if ((TIME_OF_DAY_PORT >> 3) & 1){
    tod->day_secs = (TIME_OF_DAY_PORT >> 4) + 1;
  } else {
    tod->day_secs = (TIME_OF_DAY_PORT >> 4);
  }

  // the rest of this figures out how to split up the seconds into the hour, minutes in current hour, and seconds in current minute
  if(tod->day_secs < 3600){
    tod->time_hours = 12;
  } else {
    tod->time_hours = tod->day_secs / 3600;
  }
  if(tod->time_hours > 12){
    tod->time_hours = tod->time_hours - 12;
    tod->ampm = 2;
  } else if (tod->time_hours == 12 && tod->day_secs > 3600){
    tod->ampm = 2;
  } else {
    tod->ampm = 1;
  }
  tod->time_mins = (tod->day_secs % 3600) / 60;
  tod->time_secs = (tod->day_secs % 3600) % 60;

  return 0;
}

int set_display_from_tod(tod_t tod, int *display){
  // checks for invalid parts of the tod struct
  if(tod.time_hours < 0 || tod.time_hours > 12 || tod.time_mins > 59 || tod.time_mins < 0 || tod.time_secs > 59 || tod.time_secs < 0 || tod.ampm > 2 || tod.ampm < 1){
    return 1;
  }
  // set the ampm first
  *display = (1 << (27+tod.ampm));
  
  // array representing what 0-9 represent as a decimal value from binary
  int mask[10] = {119, 36, 93, 109, 46, 107, 123, 37, 127, 111};
  // ORs it onto the display with some bit shifting
  *display = *display | (mask[tod.time_mins % 10]);
  *display = *display | (mask[tod.time_mins / 10] << 7);
  *display = *display | (mask[tod.time_hours % 10] << 14);
  // checks if can be left blank
  if(tod.time_hours >= 10){
    *display = *display | (mask[tod.time_hours / 10] << 21);
  }


  return 0;
}

int clock_update(){
  // checks for invalid port again
  if(TIME_OF_DAY_PORT < 0 || TIME_OF_DAY_PORT > 1382400){
    return 1;
  }
  tod_t tod;
  // fills in the tod struct
  set_tod_from_ports(&tod);
  // sets the display as the global variable CLOCK_DISPLAY_PORT
  set_display_from_tod(tod, &CLOCK_DISPLAY_PORT);

  return 0;
}