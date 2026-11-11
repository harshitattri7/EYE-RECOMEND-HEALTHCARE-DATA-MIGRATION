"""
Azure Key Vault Secret Management Utility
Integrates with Managed Identity (MSI) in Azure Databricks or local environment fallbacks.
"""
import os
from typing import Optional
from .logger import MigrationLogger

logger = MigrationLogger("KeyVaultManager")

class KeyVaultManager:
    def __init__(self, vault_name: Optional[str] = None):
        self.vault_name = vault_name or os.getenv("AZURE_KEY_VAULT_NAME", "kv-eyerecommend-prod-01")
        self.vault_url = f"https://{self.vault_name}.vault.azure.net"
        self._client = None
        self._init_client()

    def _init_client(self):
        # In local simulation or offline tests, avoid throwing if azure credentials aren't available
        try:
            from azure.identity import DefaultAzureCredential
            from azure.keyvault.secrets import SecretClient
            credential = DefaultAzureCredential()
            self._client = SecretClient(vault_url=self.vault_url, credential=credential)
            logger.info("Initialized Azure Key Vault Client", vault_url=self.vault_url)
        except Exception as e:
            logger.warning(
                "DefaultAzureCredential unavailable, falling back to environment/local secrets",
                error=str(e)
            )
            self._client = None

    def get_secret(self, secret_name: str, fallback_value: Optional[str] = None) -> str:
        """
        Fetch a secret by name from Azure Key Vault or fallback environment variable.
        Secret names in Key Vault use hyphens (e.g. target-postgres-connection-string),
        while environment variables use uppercase underscores.
        """
        env_var_name = secret_name.upper().replace("-", "_")
        env_val = os.getenv(env_var_name)
        if env_val:
            return env_val

        if self._client:
            try:
                secret = self._client.get_secret(secret_name)
                return secret.value
            except Exception as e:
                logger.warning(
                    f"Failed to fetch secret '{secret_name}' from Key Vault, trying fallback",
                    error=str(e)
                )

        if fallback_value is not None:
            return fallback_value

        # Standard default local development connection string
        defaults = {
            "target-postgres-connection-string": "postgresql://azure_pg_admin:TargetPassSecure2024!@localhost:5432/eyerecommend_central_db",
            "mariadb-svc-password": "migration_pass_secure",
            "salesforce-security-token": "MOCK_SALESFORCE_SECURITY_TOKEN_XYZ",
            "salesforce-user-password": "MOCK_SALESFORCE_PASSWORD"
        }
        return defaults.get(secret_name, f"mock-secret-for-{secret_name}")
