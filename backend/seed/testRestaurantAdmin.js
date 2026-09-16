require('dotenv').config();
const mongoose = require('mongoose');
const connectDB = require('../config/db');
const User = require('../models/User');
const Restaurant = require('../models/Restaurant');

async function seedRestaurantAdmin() {
  try {
    await connectDB();

    let restaurant = await Restaurant.findOne({ slug: 'tasty-bites' });
    if (!restaurant) {
      restaurant = await Restaurant.create({
        name: 'Tasty Bites Cafe',
        slug: 'tasty-bites',
      });
      console.log('Test Restaurant created');
    }

    const email = 'restaurant@scanserve.com';
    const existingUser = await User.findOne({ email });

    if (existingUser) {
      console.log('Test Restaurant Admin already exists');
    } else {
      await User.create({
        name: 'John Manager',
        email,
        password: 'RestaurantPassword123!',
        role: 'RESTAURANT_ADMIN',
        restaurant: restaurant._id,
      });
      console.log('Test Restaurant Admin created successfully');
    }

    await mongoose.connection.close();
    process.exit(0);
  } catch (error) {
    console.error('Failed to seed Restaurant Admin:', error.message);
    process.exit(1);
  }
}

seedRestaurantAdmin();

