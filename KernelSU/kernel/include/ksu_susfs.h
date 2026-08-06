/* SPDX-License-Identifier: GPL-2.0 */
#ifndef __KSU_SUSFS_COMPAT_H
#define __KSU_SUSFS_COMPAT_H

#include <linux/types.h>
#include <linux/jump_label.h>
#include <linux/cred.h>
#include <linux/susfs_def.h>

#ifdef CONFIG_KSU_SUSFS

extern bool is_ksu_domain(void);
extern bool __ksu_is_allow_uid_for_current(uid_t uid);

static inline bool susfs_is_current_ksu_domain(void)
{
	return is_ksu_domain();
}

extern struct static_key_false ksu_is_init_rc_hook_enabled;
extern struct static_key_false ksu_is_input_hook_enabled;
extern bool ksu_su_compat_enabled;
extern u32 susfs_ksu_sid;
extern u32 susfs_priv_app_sid;

void susfs_compat_init(void);
int ksu_handle_sys_read(unsigned int fd);
void ksu_handle_vfs_fstat(int fd, loff_t *kstat_size_ptr);
int ksu_handle_input_handle_event(unsigned int *type, unsigned int *code, int *value);
int ksu_handle_faccessat(int *dfd, const char __user **filename_user, int *mode, int *flags);
int ksu_handle_stat(int *dfd, const char __user **filename_user, int *flags);
int ksu_handle_execveat(int *fd, struct filename **filename_ptr, void *argv, void *envp, int *flags);
int ksu_handle_execveat_sucompat(int *fd, struct filename **filename_ptr, void *argv, void *envp, int *flags);

#else

static inline bool susfs_is_current_ksu_domain(void)
{
	return false;
}

#endif /* CONFIG_KSU_SUSFS */

#endif /* __KSU_SUSFS_COMPAT_H */
