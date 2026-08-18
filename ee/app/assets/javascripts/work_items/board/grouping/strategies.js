import { strategies as ceStrategies } from '~/work_items/board/grouping/strategies';
import { statusStrategy } from './status_strategy';

export const strategies = [...ceStrategies, statusStrategy];
