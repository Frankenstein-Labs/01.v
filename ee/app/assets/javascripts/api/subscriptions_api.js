import { buildApiUrl } from '~/api/api_utils';
import axios from '~/lib/utils/axios_utils';

export const sendHandRaiseLead = async (createHandRaiseLeadPath, params) => {
  const url = buildApiUrl(createHandRaiseLeadPath);
  const formParams = {
    namespace_id: params.namespaceId,
    company_name: params.companyName,
    first_name: params.firstName,
    last_name: params.lastName,
    phone_number: params.phoneNumber,
    country: params.country,
    state: params.state,
    comment: params.comment,
    glm_content: params.glmContent,
    product_interaction: params.productInteraction,
  };

  return axios.post(url, formParams);
};
