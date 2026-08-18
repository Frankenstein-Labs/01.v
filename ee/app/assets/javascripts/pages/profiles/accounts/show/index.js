import { initClose2faSuccessMessage } from '~/authentication/two_factor_auth';
import initProfileAccount from '~/profile/account';
import LengthValidator from '~/validators/length_validator';

initClose2faSuccessMessage();
initProfileAccount();
new LengthValidator(); // eslint-disable-line no-new
