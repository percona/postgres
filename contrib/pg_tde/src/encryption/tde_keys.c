#include "postgres.h"

#include <openssl/crypto.h>
#include <openssl/err.h>
#include <openssl/rand.h>

#include "encryption/enc_aes.h"
#include "encryption/tde_keys.h"

#ifdef FRONTEND
#include "pg_tde_fe.h"
#endif

static DecryptedTdeKey *tde_keys_alloc_decrypted_key(void);

EncryptedTdeKey *
tde_keys_encrypt_key(const DecryptedTdeKey *decrypted_key,
					 const uint8 *encryption_key,
					 const uint8 *additional_authentication_data,
					 int additional_authentication_data_size)
{
	EncryptedTdeKey *encrypted_key = palloc0_object(EncryptedTdeKey);

	memcpy(encrypted_key->key_iv, decrypted_key->iv, TDE_KEY_IV_SIZE);

	if (!RAND_bytes(encrypted_key->iv, TDE_KEY_ENCRYPTION_IV_SIZE))
		ereport(ERROR,
				errmsg("could not generate iv for key encryption: %s",
					   ERR_error_string(ERR_get_error(), NULL)));

	AesGcmEncrypt(encryption_key,

				  encrypted_key->iv,
				  TDE_KEY_ENCRYPTION_IV_SIZE,

				  additional_authentication_data,
				  additional_authentication_data_size,

				  decrypted_key->data,
				  TDE_KEY_SIZE,

				  encrypted_key->key_data,

				  encrypted_key->aead_tag,
				  TDE_KEY_ENCRYPTION_AEAD_TAG_SIZE);

	return encrypted_key;
}

DecryptedTdeKey *
tde_keys_decrypt_key(EncryptedTdeKey *encrypted_key,
					 const uint8 *decryption_key,
					 const uint8 *additional_authentication_data,
					 int additional_authentication_data_size)
{
	DecryptedTdeKey *decrypted_key;

	Assert(encrypted_key);
	Assert(decryption_key);

	decrypted_key = tde_keys_alloc_decrypted_key();

	if (!AesGcmDecrypt(decryption_key,

					   encrypted_key->iv,
					   TDE_KEY_ENCRYPTION_IV_SIZE,

					   additional_authentication_data,
					   additional_authentication_data_size,

					   encrypted_key->key_data,
					   TDE_KEY_SIZE,

					   decrypted_key->data,

					   encrypted_key->aead_tag,
					   TDE_KEY_ENCRYPTION_AEAD_TAG_SIZE))
	{
		tde_keys_free_decrypted_key(decrypted_key);
		return NULL;
	}

	memcpy(decrypted_key->iv, encrypted_key->key_iv, TDE_KEY_IV_SIZE);

	return decrypted_key;
}

void
tde_keys_free_decrypted_key(DecryptedTdeKey *decrypted_key)
{
	OPENSSL_secure_clear_free(decrypted_key, sizeof(DecryptedTdeKey));
}

DecryptedTdeKey *
tde_keys_generate_decrypted_key(void)
{
	DecryptedTdeKey *decrypted_key = tde_keys_alloc_decrypted_key();

	if (!RAND_bytes(decrypted_key->data, TDE_KEY_SIZE))
		ereport(ERROR,
				errmsg("could not generate key: %s",
					   ERR_error_string(ERR_get_error(), NULL)));

	if (!RAND_bytes(decrypted_key->iv, TDE_KEY_IV_SIZE))
		ereport(ERROR,
				errmsg("could not generate iv: %s",
					   ERR_error_string(ERR_get_error(), NULL)));

	return decrypted_key;
}

static DecryptedTdeKey *
tde_keys_alloc_decrypted_key(void)
{
	DecryptedTdeKey *decrypted_key;

	decrypted_key = OPENSSL_secure_zalloc(sizeof(DecryptedTdeKey));
	if (!decrypted_key)
		ereport(ERROR,
				errcode(ERRCODE_OUT_OF_MEMORY),
				errmsg("out of memory"));

	return decrypted_key;
}

EncryptedTdeKey *
tde_keys_new_encrypted_key(const uint8 *encryption_key,
						   const uint8 *additional_authentication_data,
						   int additional_authentication_data_size)
{
	DecryptedTdeKey *decrypted_key;
	EncryptedTdeKey *encrypted_key;

	decrypted_key = tde_keys_generate_decrypted_key();
	encrypted_key = tde_keys_encrypt_key(decrypted_key,
										 encryption_key,
										 additional_authentication_data,
										 additional_authentication_data_size);
	tde_keys_free_decrypted_key(decrypted_key);

	return encrypted_key;
}
