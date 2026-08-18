import GoogleArtifactRegistryApp from 'ee_component/packages_and_registries/google_artifact_registry/index';

const app = GoogleArtifactRegistryApp();

if (app) {
  app.attachBreadcrumb();
  app.attachMainComponent();
}
