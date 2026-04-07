import React from 'react';
import Calendar from 'react-calendar';
import 'react-calendar/dist/Calendar.css';
import './css/Calendar.css';

function CalendarComponent({ selectedDate, handleDateChange }) {
  return (
    <div className="calendar-component-wrapper">
      <h2 className="calendar-title">Select a Day</h2>
      <div className="calendar-container">
        <Calendar
          onChange={handleDateChange}
          value={selectedDate}
          calendarType="hebrew"
        />
      </div>
    </div>
  );
}

export default CalendarComponent;