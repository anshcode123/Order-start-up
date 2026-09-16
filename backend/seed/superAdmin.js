require('dotenv').config();
const mongoose = require('mongoose');
const connectDB = require('../config/db');
const User = require('../models/User');

async function seedSuperAdmin() {
  try {
    await connectDB();

    const name = process.env.SUPER_ADMIN_NAME;
    const email = process.env.SUPER_ADMIN_EMAIL;
    const password = process.env.SUPER_ADMIN_PASSWORD;

    if (!email || !password) {
      console.error('Error: SUPER_ADMIN_EMAIL and SUPER_ADMIN_PASSWORD must be defined in environment.');
      process.exit(1);
    }

    const existingSuperAdmin = await User.findOne({ email: email.toLowerCase() });

    if (existingSuperAdmin) {
      console.log('Super Admin already exists');
    } else {
      await User.create({
        name: name || 'Super Admin',
        email: email.toLowerCase(),
        password,
        role: 'SUPER_ADMIN',
        restaurant: null,
      });
      console.log('Super Admin created successfully');
    }

    await mongoose.connection.close();
    process.exit(0);
  } catch (error) {
    console.error('Failed to seed Super Admin:', error.message);
    process.exit(1);
  }
}

seedSuperAdmin();

