import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from '../users/user.entity';

/** One point in a run path: lat, lng, timestamp (ms). */
export interface PathPoint {
  lat: number;
  lng: number;
  t: number;
}

@Entity({ name: 'runs' })
export class Run {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'started_at', type: 'timestamptz' })
  startedAt: Date;

  @Column({ name: 'ended_at', type: 'timestamptz' })
  endedAt: Date;

  @Column({ type: 'jsonb', default: [] })
  path: PathPoint[];

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
