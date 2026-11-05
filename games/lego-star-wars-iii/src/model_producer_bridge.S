.text
.globl _producer_hook
_producer_hook:
 pushfl
 pushal
 movl %esp,%eax
 subl $3072,%esp
 andl $-16,%esp
 movl %esp,%edi
 fxsave (%edi)
 movl %eax,1108(%edi)
 movl 40(%eax),%edx
 movl %edx,1752(%edi)
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
 movl $0,1756(%edi)
 movl $0,1112(%edi)
 fninit
 ldmxcsr _model_producer_default_mxcsr
 pushl %edi
 call _model_producer_c
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

.globl _model_producer_inner
_model_producer_inner:
 pushfl
 pushal
 movl 40(%esp),%edi
 fxsave 1120(%edi)
 movl 1096(%edi),%eax
 movl %eax,%fs:52
 pushl %edi
 pushl 1112(%edi)
 pushl 1752(%edi)
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
 call *4(%esp)
 pushfl
 pushal
 movl 44(%esp),%edi
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
 ldmxcsr _model_producer_default_mxcsr
 addl $48,%esp
 popal
 popfl
 ret



