import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity({ name: 'users' })
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'firebase_uid', unique: true })
  firebaseUid: string;

  @Column()
  username: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}

