import { WORKSPACE_STATES } from '../common/constants';

export {
  I18N_LOADING_WORKSPACES_FAILED,
  WORKSPACES_LIST_PAGE_SIZE,
  WORKSPACES_LIST_POLL_INTERVAL,
  CLICK_NEW_WORKSPACE_BUTTON_EVENT_NAME,
} from '../common/constants';

export const ROUTES = {
  index: 'index',
  new: 'new',
};

export const PROJECT_VISIBILITY = {
  public: 'public',
  private: 'private',
  internal: 'internal',
};

export const DEFAULT_DESIRED_STATE = WORKSPACE_STATES.running;
export const USER_ROOT_DEVFILE_PATH = ['.devfile.yaml', '.devfile.yml'];
export const USER_DEVFILE_FOLDER_PATH = '.devfile';
export const DEFAULT_DEVFILE_OPTION = 'default_devfile';

export const WORKSPACE_VARIABLE_INPUT_TYPE_ENUM = {
  env: 'ENVIRONMENT',
};
