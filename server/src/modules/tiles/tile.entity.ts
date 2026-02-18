import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity({ name: 'tiles' })
export class Tile {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'row_index', type: 'int' })
  rowIndex: number;

  @Column({ name: 'col_index', type: 'int' })
  colIndex: number;

  @Column({ name: 'min_lat', type: 'double precision' })
  minLat: number;

  @Column({ name: 'min_lng', type: 'double precision' })
  minLng: number;

  @Column({ name: 'max_lat', type: 'double precision' })
  maxLat: number;

  @Column({ name: 'max_lng', type: 'double precision' })
  maxLng: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}

