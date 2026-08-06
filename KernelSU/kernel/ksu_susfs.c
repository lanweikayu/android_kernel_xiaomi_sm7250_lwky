// SPDX-License-Identifier: GPL-2.0
/*
 * Compatibility layer for SUSFS against backslashxx/KernelSU.
 *
 * SUSFS historically relied on a set of ksu_* symbols and static keys
 * exported by the original KernelSU implementation. backslashxx/KernelSU
 * provides the same functionality through its own hooks, so this shim
 * exposes the old SUSFS-facing names without duplicating hook logic.
 */

#include "kernel_includes.h"
#include "include/ksu.h"
#include "include/ksu_susfs.h"

#ifdef CONFIG_KSU_SUSFS

#include "feature/sucompat.h"
#include "runtime/ksud.h"

DEFINE_STATIC_KEY_FALSE(ksu_is_init_rc_hook_enabled);
DEFINE_STATIC_KEY_FALSE(ksu_is_input_hook_enabled);
u32 susfs_ksu_sid;
u32 susfs_priv_app_sid;

int ksu_handle_sys_read(unsigned int fd)
{
	ksu_handle_sys_read_fd(fd);
	return 0;
}

void ksu_handle_vfs_fstat(int fd, loff_t *kstat_size_ptr)
{
	// backslashxx handles init.rc stat spoofing through its own
	// syscall table / branch-link hooks, so no-op here.
}

int ksu_handle_input_handle_event(unsigned int *type, unsigned int *code, int *value)
{
	// backslashxx registers an input handler for safe mode detection;
	// the legacy inline input hook is intentionally not installed.
	return 0;
}

void susfs_compat_init(void)
{
	static_branch_enable(&ksu_is_init_rc_hook_enabled);
	static_branch_enable(&ksu_is_input_hook_enabled);

	security_secctx_to_secid("u:r:ksu:s0", strlen("u:r:ksu:s0"), &susfs_ksu_sid);
	security_secctx_to_secid("u:r:priv_app:s0", strlen("u:r:priv_app:s0"), &susfs_priv_app_sid);
}

#endif /* CONFIG_KSU_SUSFS */
