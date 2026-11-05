.text
.globl _user_mapping_mapper_entry
_user_mapping_mapper_entry:
 pushfl
 pushal
 movl %esp,%eax
 subl $3072,%esp
 andl $-16,%esp
 movl %esp,%edi
 fxsave (%edi)
 movl %eax,1108(%edi)
 movl $0,1752(%edi)
 leal 36(%eax),%edx
 movl %edx,1104(%edi)
 movl %eax,%esi
 leal 1024(%edi),%edx
 movl $9,%ecx
 cld
1: movl (%esi),%eax
 movl %eax,(%edx)
 addl $4,%esi
 addl $4,%edx
 loop 1b
 movl %fs:52,%eax
 movl %eax,1096(%edi)
 movl $0,1764(%edi)
 movl $0,1112(%edi)
 fninit
 ldmxcsr _user_mapping_default_mxcsr
 pushl %edi
 call _user_mapping_bridge_c
 addl $4,%esp
 movl %esp,%edi
 movl 1108(%edi),%edx
 leal 1060(%edi),%esi
 movl $9,%ecx
 cld
2: movl (%esi),%eax
 movl %eax,(%edx)
 addl $4,%esi
 addl $4,%edx
 loop 2b
 movl 1100(%edi),%eax
 movl %eax,%fs:52
 fxrstor 512(%edi)
 movl 1108(%edi),%esp
 popal
 popfl
 ret

.globl _user_mapping_setter_entry
_user_mapping_setter_entry:
 pushfl
 pushal
 movl %esp,%eax
 subl $3072,%esp
 andl $-16,%esp
 movl %esp,%edi
 fxsave (%edi)
 movl %eax,1108(%edi)
 movl $1,1752(%edi)
 leal 36(%eax),%edx
 movl %edx,1104(%edi)
 movl %eax,%esi
 leal 1024(%edi),%edx
 movl $9,%ecx
 cld
1: movl (%esi),%eax
 movl %eax,(%edx)
 addl $4,%esi
 addl $4,%edx
 loop 1b
 movl %fs:52,%eax
 movl %eax,1096(%edi)
 movl $0,1764(%edi)
 movl $0,1112(%edi)
 fninit
 ldmxcsr _user_mapping_default_mxcsr
 pushl %edi
 call _user_mapping_bridge_c
 addl $4,%esp
 movl %esp,%edi
 movl 1108(%edi),%edx
 leal 1060(%edi),%esi
 movl $9,%ecx
 cld
2: movl (%esi),%eax
 movl %eax,(%edx)
 addl $4,%esi
 addl $4,%edx
 loop 2b
 movl 1100(%edi),%eax
 movl %eax,%fs:52
 fxrstor 512(%edi)
 movl 1108(%edi),%esp
 popal
 popfl
 ret

.globl _user_mapping_reset_all_entry
_user_mapping_reset_all_entry:
 pushfl
 pushal
 movl %esp,%eax
 subl $3072,%esp
 andl $-16,%esp
 movl %esp,%edi
 fxsave (%edi)
 movl %eax,1108(%edi)
 movl $2,1752(%edi)
 leal 36(%eax),%edx
 movl %edx,1104(%edi)
 movl %eax,%esi
 leal 1024(%edi),%edx
 movl $9,%ecx
 cld
1: movl (%esi),%eax
 movl %eax,(%edx)
 addl $4,%esi
 addl $4,%edx
 loop 1b
 movl %fs:52,%eax
 movl %eax,1096(%edi)
 movl $0,1764(%edi)
 movl $0,1112(%edi)
 fninit
 ldmxcsr _user_mapping_default_mxcsr
 pushl %edi
 call _user_mapping_bridge_c
 addl $4,%esp
 movl %esp,%edi
 movl 1108(%edi),%edx
 leal 1060(%edi),%esi
 movl $9,%ecx
 cld
2: movl (%esi),%eax
 movl %eax,(%edx)
 addl $4,%esi
 addl $4,%edx
 loop 2b
 movl 1100(%edi),%eax
 movl %eax,%fs:52
 fxrstor 512(%edi)
 movl 1108(%edi),%esp
 popal
 popfl
 ret

.globl _user_mapping_reset_01_entry
_user_mapping_reset_01_entry:
 pushfl
 pushal
 movl %esp,%eax
 subl $3072,%esp
 andl $-16,%esp
 movl %esp,%edi
 fxsave (%edi)
 movl %eax,1108(%edi)
 movl $3,1752(%edi)
 leal 36(%eax),%edx
 movl %edx,1104(%edi)
 movl %eax,%esi
 leal 1024(%edi),%edx
 movl $9,%ecx
 cld
1: movl (%esi),%eax
 movl %eax,(%edx)
 addl $4,%esi
 addl $4,%edx
 loop 1b
 movl %fs:52,%eax
 movl %eax,1096(%edi)
 movl $0,1764(%edi)
 movl $0,1112(%edi)
 fninit
 ldmxcsr _user_mapping_default_mxcsr
 pushl %edi
 call _user_mapping_bridge_c
 addl $4,%esp
 movl %esp,%edi
 movl 1108(%edi),%edx
 leal 1060(%edi),%esi
 movl $9,%ecx
 cld
2: movl (%esi),%eax
 movl %eax,(%edx)
 addl $4,%esi
 addl $4,%edx
 loop 2b
 movl 1100(%edi),%eax
 movl %eax,%fs:52
 fxrstor 512(%edi)
 movl 1108(%edi),%esp
 popal
 popfl
 ret

.globl _user_mapping_initializer_entry
_user_mapping_initializer_entry:
 pushfl
 pushal
 movl %esp,%eax
 subl $3072,%esp
 andl $-16,%esp
 movl %esp,%edi
 fxsave (%edi)
 movl %eax,1108(%edi)
 movl $4,1752(%edi)
 leal 36(%eax),%edx
 movl %edx,1104(%edi)
 movl %eax,%esi
 leal 1024(%edi),%edx
 movl $9,%ecx
 cld
1: movl (%esi),%eax
 movl %eax,(%edx)
 addl $4,%esi
 addl $4,%edx
 loop 1b
 movl %fs:52,%eax
 movl %eax,1096(%edi)
 movl $0,1764(%edi)
 movl $0,1112(%edi)
 fninit
 ldmxcsr _user_mapping_default_mxcsr
 pushl %edi
 call _user_mapping_bridge_c
 addl $4,%esp
 movl %esp,%edi
 movl 1108(%edi),%edx
 leal 1060(%edi),%esi
 movl $9,%ecx
 cld
2: movl (%esi),%eax
 movl %eax,(%edx)
 addl $4,%esi
 addl $4,%edx
 loop 2b
 movl 1100(%edi),%eax
 movl %eax,%fs:52
 fxrstor 512(%edi)
 movl 1108(%edi),%esp
 popal
 popfl
 ret

.globl _user_mapping_user0_a_entry
_user_mapping_user0_a_entry:
 pushfl
 pushal
 movl %esp,%eax
 subl $3072,%esp
 andl $-16,%esp
 movl %esp,%edi
 fxsave (%edi)
 movl %eax,1108(%edi)
 movl $5,1752(%edi)
 leal 36(%eax),%edx
 movl %edx,1104(%edi)
 movl %eax,%esi
 leal 1024(%edi),%edx
 movl $9,%ecx
 cld
1: movl (%esi),%eax
 movl %eax,(%edx)
 addl $4,%esi
 addl $4,%edx
 loop 1b
 movl %fs:52,%eax
 movl %eax,1096(%edi)
 movl $0,1764(%edi)
 movl $0,1112(%edi)
 fninit
 ldmxcsr _user_mapping_default_mxcsr
 pushl %edi
 call _user_mapping_bridge_c
 addl $4,%esp
 movl %esp,%edi
 movl 1108(%edi),%edx
 leal 1060(%edi),%esi
 movl $9,%ecx
 cld
2: movl (%esi),%eax
 movl %eax,(%edx)
 addl $4,%esi
 addl $4,%edx
 loop 2b
 movl 1100(%edi),%eax
 movl %eax,%fs:52
 fxrstor 512(%edi)
 movl 1108(%edi),%esp
 popal
 popfl
 ret

.globl _user_mapping_user0_b_entry
_user_mapping_user0_b_entry:
 pushfl
 pushal
 movl %esp,%eax
 subl $3072,%esp
 andl $-16,%esp
 movl %esp,%edi
 fxsave (%edi)
 movl %eax,1108(%edi)
 movl $6,1752(%edi)
 leal 36(%eax),%edx
 movl %edx,1104(%edi)
 movl %eax,%esi
 leal 1024(%edi),%edx
 movl $9,%ecx
 cld
1: movl (%esi),%eax
 movl %eax,(%edx)
 addl $4,%esi
 addl $4,%edx
 loop 1b
 movl %fs:52,%eax
 movl %eax,1096(%edi)
 movl $0,1764(%edi)
 movl $0,1112(%edi)
 fninit
 ldmxcsr _user_mapping_default_mxcsr
 pushl %edi
 call _user_mapping_bridge_c
 addl $4,%esp
 movl %esp,%edi
 movl 1108(%edi),%edx
 leal 1060(%edi),%esi
 movl $9,%ecx
 cld
2: movl (%esi),%eax
 movl %eax,(%edx)
 addl $4,%esi
 addl $4,%edx
 loop 2b
 movl 1100(%edi),%eax
 movl %eax,%fs:52
 fxrstor 512(%edi)
 movl 1108(%edi),%esp
 popal
 popfl
 ret

.globl _user_mapping_poller_entry
_user_mapping_poller_entry:
 pushfl
 pushal
 movl %esp,%eax
 subl $3072,%esp
 andl $-16,%esp
 movl %esp,%edi
 fxsave (%edi)
 movl %eax,1108(%edi)
 movl $7,1752(%edi)
 leal 36(%eax),%edx
 movl %edx,1104(%edi)
 movl %eax,%esi
 leal 1024(%edi),%edx
 movl $9,%ecx
 cld
1: movl (%esi),%eax
 movl %eax,(%edx)
 addl $4,%esi
 addl $4,%edx
 loop 1b
 movl %fs:52,%eax
 movl %eax,1096(%edi)
 movl $0,1764(%edi)
 movl $0,1112(%edi)
 fninit
 ldmxcsr _user_mapping_default_mxcsr
 pushl %edi
 call _user_mapping_bridge_c
 addl $4,%esp
 movl %esp,%edi
 movl 1108(%edi),%edx
 leal 1060(%edi),%esi
 movl $9,%ecx
 cld
2: movl (%esi),%eax
 movl %eax,(%edx)
 addl $4,%esi
 addl $4,%edx
 loop 2b
 movl 1100(%edi),%eax
 movl %eax,%fs:52
 fxrstor 512(%edi)
 movl 1108(%edi),%esp
 popal
 popfl
 ret

.globl _user_mapping_bridge_inner
_user_mapping_bridge_inner:
 pushfl
 pushal
 movl 40(%esp),%edi
 fxsave 1120(%edi)
 movl 1096(%edi),%eax
 movl %eax,%fs:52
 pushl %edi
 pushl 1112(%edi)
 pushl 1760(%edi)
 pushl 1756(%edi)
 subl $36,%esp
 movl %esp,%edx
 leal 1024(%edi),%esi
 movl $9,%ecx
 cld
3: movl (%esi),%eax
 movl %eax,(%edx)
 addl $4,%esi
 addl $4,%edx
 loop 3b
 fxrstor (%edi)
 popal
 popfl
 call *8(%esp)
 pushfl
 pushal
 movl 48(%esp),%edi
 fxsave 512(%edi)
 movl %fs:52,%eax
 movl %eax,1100(%edi)
 movl %esp,%esi
 leal 1060(%edi),%edx
 movl $9,%ecx
 cld
4: movl (%esi),%eax
 movl %eax,(%edx)
 addl $4,%esi
 addl $4,%edx
 loop 4b
 fninit
 ldmxcsr _user_mapping_default_mxcsr
 addl $52,%esp
 popal
 popfl
 ret



