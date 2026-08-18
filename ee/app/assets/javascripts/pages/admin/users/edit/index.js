import '~/pages/admin/users/edit';
import initPasswordValidator from 'ee/password/password_validator';
import { initPipelineMinutes } from '../pipeline_minutes/init_pipeline_minutes';

initPipelineMinutes();
initPasswordValidator({ allowNoPassword: true });
