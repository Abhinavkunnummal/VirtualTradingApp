import mongoose, { Schema, Document } from 'mongoose';

export type ExperienceLevel = 'BEGINNER' | 'INTERMEDIATE' | 'ADVANCED' | 'PRO';
export type UserStatus = 'ACTIVE' | 'SUSPENDED';

export interface IUser extends Document {
  email: string;
  passwordHash: string;
  displayName: string;
  avatarUrl?: string;
  experienceLevel: ExperienceLevel;
  preferredMarkets: string[];
  status: UserStatus;
  createdAt: Date;
  updatedAt: Date;
}

const UserSchema = new Schema<IUser>(
  {
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      index: true,
    },
    passwordHash: {
      type: String,
      required: true,
    },
    displayName: {
      type: String,
      required: true,
      trim: true,
    },
    avatarUrl: {
      type: String,
      default: null,
    },
    experienceLevel: {
      type: String,
      enum: ['BEGINNER', 'INTERMEDIATE', 'ADVANCED', 'PRO'],
      default: 'BEGINNER',
    },
    preferredMarkets: {
      type: [String],
      default: ['NSE', 'CRYPTO'],
    },
    status: {
      type: String,
      enum: ['ACTIVE', 'SUSPENDED'],
      default: 'ACTIVE',
    },
  },
  {
    timestamps: true,
  }
);

export const User = mongoose.models.User || mongoose.model<IUser>('User', UserSchema);
