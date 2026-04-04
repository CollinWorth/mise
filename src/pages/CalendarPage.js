import React, { useState, useEffect } from 'react';
import CalendarComponent from './CalendarComponent';
import DayPlanner from '../components/DayPlanner';
import './css/Calendar.css';

function CalendarPage({ user }) {
  const daysOfWeek = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  const [recipes, setRecipes] = useState([]);
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [selectedDay, setSelectedDay] = useState('Sunday');
  const [selectedWeek, setSelectedWeek] = useState('');
  const [dayRecipes, setDayRecipes] = useState([]);

  useEffect(() => {
    const userId = user.id || user._id;
    const fetchRecipes = async () => {
      try {
        const response = await fetch(`http://localhost:8000/recipes/user/${userId}`);
        if (response.ok) {
          const data = await response.json();
          setRecipes(data);
        }
      } catch (err) {
        console.error('Error fetching recipes:', err);
      }
    };
    fetchRecipes();
  }, [user]);

  useEffect(() => {
    const fetchDayMeals = async () => {
      try {
        const formattedDate = new Date(selectedDate).toISOString().split('T')[0];
        const response = await fetch(
          `http://localhost:8000/mealPlans/${formattedDate}/${user.id || user._id}`
        );
        if (response.ok) {
          const mealPlans = await response.json();
          const recipeIds = mealPlans.map((meal) => meal.recipe_id);
          const recipePromises = recipeIds.map((id) =>
            fetch(`http://localhost:8000/recipes/${id}`).then((res) => res.json())
          );
          const recipes = await Promise.all(recipePromises);
          setDayRecipes(recipes);
        } else {
          console.error('Failed to fetch day meals:', response.statusText);
        }
      } catch (error) {
        console.error('Error fetching day meals:', error);
      }
    };
    if (selectedDate && user) {
      fetchDayMeals();
    }
  }, [selectedDate, user]);

  const handleDateChange = (date) => {
    setSelectedDate(date);
    const dayIndex = new Date(date).getDay();
    setSelectedDay(daysOfWeek[dayIndex]);
    const startOfWeek = new Date(date);
    startOfWeek.setDate(date.getDate() - date.getDay());
    const endOfWeek = new Date(startOfWeek);
    endOfWeek.setDate(startOfWeek.getDate() + 6);
    const formattedWeek = `${startOfWeek.getMonth() + 1}/${startOfWeek.getDate()}-${endOfWeek.getMonth() + 1}/${endOfWeek.getDate()}`;
    setSelectedWeek(formattedWeek);
  };

  return (
    <div className="calendar-page-wrapper">
      {/* Sticky Header */}
      <div className="calendar-header">
        <h1>Weekly Planner</h1>
      </div>
      <div className="calendar-layout">
        {/* Left Sidebar */}
        <aside className="calendar-sidebar-left">
          <h3>Navigation</h3>
          <ul>
            <li>📅 Calendar</li>
            <li>🍽️ Day Plan</li>
          </ul>
        </aside>
        {/* Main Section */}
        <main className="calendar-main">
          <CalendarComponent
            selectedDate={selectedDate}
            handleDateChange={handleDateChange}
          />
          <DayPlanner
            user={user}
            recipes={dayRecipes}
            selectedDay={selectedDay}
            setSelectedDay={setSelectedDay}
            selectedWeek={selectedWeek}
            selectedDate={selectedDate}
            setSelectedDate={setSelectedDate}
          />
        </main>
      </div>
    </div>
  );
}

export default CalendarPage;