import Api from '~/api';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { isNumeric } from '~/lib/utils/number_utils';
import { EDIT_PATH_ID_FORMAT, PIPELINE_CONFIGURATION_PATH_FORMAT } from './constants';

export const injectIdIntoEditPath = (path, id) => {
  if (!path || !path.match(EDIT_PATH_ID_FORMAT) || !isNumeric(id)) {
    return '';
  }

  return path.replace(EDIT_PATH_ID_FORMAT, `/${id}/`);
};

export const initialiseFormData = () => ({
  name: null,
  description: null,
  pipelineConfigurationFullPath: null,
  color: null,
  projects: null,
});

export const getSubmissionParams = (formData, pipelineConfigurationFullPathEnabled) => {
  const params = {
    name: formData.name,
    description: formData.description,
    color: formData.color,
    default: formData.default,
    projects: formData.projects
      ? {
          addProjects: formData.projects.addProjects || [],
          removeProjects: formData.projects.removeProjects || [],
        }
      : { addProjects: [], removeProjects: [] },
  };

  if (
    pipelineConfigurationFullPathEnabled &&
    formData.pipelineConfigurationFullPath !== undefined
  ) {
    params.pipelineConfigurationFullPath = formData.pipelineConfigurationFullPath;
  }

  return params;
};

export const getPipelineConfigurationPathParts = (path) => {
  const [, file, group, project] = path.match(PIPELINE_CONFIGURATION_PATH_FORMAT) || [];

  return { file, group, project };
};

export const validatePipelineConfirmationFormat = (path) => {
  return PIPELINE_CONFIGURATION_PATH_FORMAT.test(path);
};

export const fetchPipelineConfigurationFileExists = async (path) => {
  const { file, group, project } = getPipelineConfigurationPathParts(path);

  if (!file || !group || !project) {
    return false;
  }

  try {
    const { status } = await Api.getRawFile(`${group}/${project}`, file);

    return status === HTTP_STATUS_OK;
  } catch (e) {
    return false;
  }
};
