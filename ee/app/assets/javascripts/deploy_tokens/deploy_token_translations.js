import { s__ } from '~/locale';
import ceTranslations from '~/deploy_tokens/deploy_token_translations';

const translations = {
  ...ceTranslations,
  topLevelGroupReadVirtualRegistryHelp: s__(
    'DeployTokens|Allows read-only access to container images through the dependency proxy and read-only access to virtual registries.',
  ),
};

export default translations;
