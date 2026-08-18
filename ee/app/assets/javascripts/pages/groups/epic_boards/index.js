import initEpicBoards from 'ee/epic_boards';
import { addShortcutsExtension } from '~/behaviors/shortcuts';
import ShortcutsNavigation from '~/behaviors/shortcuts/shortcuts_navigation';

addShortcutsExtension(ShortcutsNavigation);
initEpicBoards();
