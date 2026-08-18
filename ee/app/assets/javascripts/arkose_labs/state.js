import { observable } from '~/lib/utils/observable';

export const ARKOSE_STATE_KEY = 'arkose_signup_state';

const INITIAL_STATE = {
  token: '',
  challengeBypassed: false,
  iframeShown: false,
  awaitingToken: false,
};

export const arkoseState = observable(ARKOSE_STATE_KEY, INITIAL_STATE);

export const resetArkoseState = () => {
  Object.assign(arkoseState, INITIAL_STATE);
};
