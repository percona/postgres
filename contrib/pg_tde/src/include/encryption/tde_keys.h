#ifndef TDE_KEYS_H
#define TDE_KEYS_H

#include "postgres.h"

#include "utils/resowner.h"

#include "catalog/tde_principal_key.h"

#define TDE_KEY_SIZE 16
#define TDE_KEY_IV_SIZE 16
#define TDE_KEY_ENCRYPTION_IV_SIZE 16
#define TDE_KEY_ENCRYPTION_AEAD_TAG_SIZE 16

typedef struct EncryptedTdeKey
{
	uint8		key_data[TDE_KEY_SIZE];
	uint8		key_iv[TDE_KEY_IV_SIZE];

	/* IV and tag used when encrypting the key itself */
	uint8		iv[TDE_KEY_ENCRYPTION_IV_SIZE];
	uint8		aead_tag[TDE_KEY_ENCRYPTION_AEAD_TAG_SIZE];
} EncryptedTdeKey;

typedef struct DecryptedTdeKey
{
	uint8		data[TDE_KEY_SIZE];
	uint8		iv[TDE_KEY_IV_SIZE];

	ResourceOwner owner;
} DecryptedTdeKey;

extern EncryptedTdeKey *tde_keys_encrypt_key(const DecryptedTdeKey *decrypted_key, const uint8 *encryption_key, const uint8 *additional_authentication_data, int additional_authentication_data_size);
extern DecryptedTdeKey *tde_keys_decrypt_key(EncryptedTdeKey *encrypted_key, const uint8 *decryption_key, const uint8 *additional_authentication_data, int additional_authentication_data_size);
extern void tde_keys_free_decrypted_key(DecryptedTdeKey *decrypted_key);
extern DecryptedTdeKey *tde_keys_generate_decrypted_key(void);
extern EncryptedTdeKey *tde_keys_new_encrypted_key(const uint8 *encryption_key, const uint8 *additional_authentication_data, int additional_authentication_data_size);

#endif
