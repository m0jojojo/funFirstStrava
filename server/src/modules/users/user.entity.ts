import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity({ name: 'users' })
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'firebase_uid', unique: true })
  firebaseUid: string;

  @Column()
  username: string;

  @Column({ name: 'fcm_token', type: 'varchar', nullable: true })
  fcmToken: string | null;

  @Column({ name: 'territory_color', type: 'varchar', length: 16, nullable: true })
  territoryColor: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}

