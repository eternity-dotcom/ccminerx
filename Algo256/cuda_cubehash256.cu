#include "cuda_helper.h"

#define CUBEHASH_ROUNDS 16 /* this is r for CubeHashr/b */
#define CUBEHASH_BLOCKBYTES 32 /* this is b for CubeHashr/b */

#ifdef __INTELLISENSE__
/* just for vstudio code colors */
#define __CUDA_ARCH__ 520
#endif

#if __CUDA_ARCH__ < 350
#define LROT(x,bits) ((x << bits) | (x >> (32 - bits)))
#else
#define LROT(x, bits) __funnelshift_l(x, x, bits)
#endif

#define TPB35 576
#define TPB50 1024

#define ROTATEUPWARDS7(a)  LROT(a,7)
#define ROTATEUPWARDS11(a) LROT(a,11)

__device__ __forceinline__ void rrounds(uint32_t x[2][2][2][2][2])
{
	int r;

	uint32_t x0[2][2][2][2];
	uint32_t x1[2][2][2][2];

	for (r = 0; r < CUBEHASH_ROUNDS; r += 2) {
		/* "rotate x_0jklm upwards by 7 bits" */
		x0[0][0][0][0] = ROTATEUPWARDS7(x[0][0][0][0][0]);
		x0[0][0][0][1] = ROTATEUPWARDS7(x[0][0][0][0][1]);
		x0[0][0][1][0] = ROTATEUPWARDS7(x[0][0][0][1][0]);
		x0[0][0][1][1] = ROTATEUPWARDS7(x[0][0][0][1][1]);
		x0[0][1][0][0] = ROTATEUPWARDS7(x[0][0][1][0][0]);
		x0[0][1][0][1] = ROTATEUPWARDS7(x[0][0][1][0][1]);
		x0[0][1][1][0] = ROTATEUPWARDS7(x[0][0][1][1][0]);
		x0[0][1][1][1] = ROTATEUPWARDS7(x[0][0][1][1][1]);
		x0[1][0][0][0] = ROTATEUPWARDS7(x[0][1][0][0][0]);
		x0[1][0][0][1] = ROTATEUPWARDS7(x[0][1][0][0][1]);
		x0[1][0][1][0] = ROTATEUPWARDS7(x[0][1][0][1][0]);
		x0[1][0][1][1] = ROTATEUPWARDS7(x[0][1][0][1][1]);
		x0[1][1][0][0] = ROTATEUPWARDS7(x[0][1][1][0][0]);
		x0[1][1][0][1] = ROTATEUPWARDS7(x[0][1][1][0][1]);
		x0[1][1][1][0] = ROTATEUPWARDS7(x[0][1][1][1][0]);
		x0[1][1][1][1] = ROTATEUPWARDS7(x[0][1][1][1][1]);

		/* "add x_0jklm into x_1jklm modulo 2^32" */
		x1[0][0][0][0] = x[1][0][0][0][0] + x[0][0][0][0][0];
		x1[0][0][0][1] = x[1][0][0][0][1] + x[0][0][0][0][1];
		x1[0][0][1][0] = x[1][0][0][1][0] + x[0][0][0][1][0];
		x1[0][0][1][1] = x[1][0][0][1][1] + x[0][0][0][1][1];
		x1[0][1][0][0] = x[1][0][1][0][0] + x[0][0][1][0][0];
		x1[0][1][0][1] = x[1][0][1][0][1] + x[0][0][1][0][1];
		x1[0][1][1][0] = x[1][0][1][1][0] + x[0][0][1][1][0];
		x1[0][1][1][1] = x[1][0][1][1][1] + x[0][0][1][1][1];
		x1[1][0][0][0] = x[1][1][0][0][0] + x[0][1][0][0][0];
		x1[1][0][0][1] = x[1][1][0][0][1] + x[0][1][0][0][1];
		x1[1][0][1][0] = x[1][1][0][1][0] + x[0][1][0][1][0];
		x1[1][0][1][1] = x[1][1][0][1][1] + x[0][1][0][1][1];
		x1[1][1][0][0] = x[1][1][1][0][0] + x[0][1][1][0][0];
		x1[1][1][0][1] = x[1][1][1][0][1] + x[0][1][1][0][1];
		x1[1][1][1][0] = x[1][1][1][1][0] + x[0][1][1][1][0];
		x1[1][1][1][1] = x[1][1][1][1][1] + x[0][1][1][1][1];

		/* "xor x_1~jklm into x_0jklm" */
		x[0][0][0][0][0] = x0[0][0][0][0] ^ x1[1][0][0][0];
		x[0][0][0][0][1] = x0[0][0][0][1] ^ x1[1][0][0][1];
		x[0][0][0][1][0] = x0[0][0][1][0] ^ x1[1][0][1][0];
		x[0][0][0][1][1] = x0[0][0][1][1] ^ x1[1][0][1][1];
		x[0][0][1][0][0] = x0[0][1][0][0] ^ x1[1][1][0][0];
		x[0][0][1][0][1] = x0[0][1][0][1] ^ x1[1][1][0][1];
		x[0][0][1][1][0] = x0[0][1][1][0] ^ x1[1][1][1][0];
		x[0][0][1][1][1] = x0[0][1][1][1] ^ x1[1][1][1][1];
		x[0][1][0][0][0] = x0[1][0][0][0] ^ x1[0][0][0][0];
		x[0][1][0][0][1] = x0[1][0][0][1] ^ x1[0][0][0][1];
		x[0][1][0][1][0] = x0[1][0][1][0] ^ x1[0][0][1][0];
		x[0][1][0][1][1] = x0[1][0][1][1] ^ x1[0][0][1][1];
		x[0][1][1][0][0] = x0[1][1][0][0] ^ x1[0][1][0][0];
		x[0][1][1][0][1] = x0[1][1][0][1] ^ x1[0][1][0][1];
		x[0][1][1][1][0] = x0[1][1][1][0] ^ x1[0][1][1][0];
		x[0][1][1][1][1] = x0[1][1][1][1] ^ x1[0][1][1][1];

		/* "rotate x_0jklm upwards by 11 bits" */
		x0[0][0][0][0] = ROTATEUPWARDS11(x[0][0][0][0][0]);
		x0[0][0][0][1] = ROTATEUPWARDS11(x[0][0][0][0][1]);
		x0[0][0][1][0] = ROTATEUPWARDS11(x[0][0][0][1][0]);
		x0[0][0][1][1] = ROTATEUPWARDS11(x[0][0][0][1][1]);
		x0[0][1][0][0] = ROTATEUPWARDS11(x[0][0][1][0][0]);
		x0[0][1][0][1] = ROTATEUPWARDS11(x[0][0][1][0][1]);
		x0[0][1][1][0] = ROTATEUPWARDS11(x[0][0][1][1][0]);
		x0[0][1][1][1] = ROTATEUPWARDS11(x[0][0][1][1][1]);
		x0[1][0][0][0] = ROTATEUPWARDS11(x[0][1][0][0][0]);
		x0[1][0][0][1] = ROTATEUPWARDS11(x[0][1][0][0][1]);
		x0[1][0][1][0] = ROTATEUPWARDS11(x[0][1][0][1][0]);
		x0[1][0][1][1] = ROTATEUPWARDS11(x[0][1][0][1][1]);
		x0[1][1][0][0] = ROTATEUPWARDS11(x[0][1][1][0][0]);
		x0[1][1][0][1] = ROTATEUPWARDS11(x[0][1][1][0][1]);
		x0[1][1][1][0] = ROTATEUPWARDS11(x[0][1][1][1][0]);
		x0[1][1][1][1] = ROTATEUPWARDS11(x[0][1][1][1][1]);

		/* "add x_0jklm into x_1~jk~lm modulo 2^32" */
		x[1][1][0][1][0] = x1[1][0][1][0] + x[0][0][0][0][0];
		x[1][1][0][1][1] = x1[1][0][1][1] + x[0][0][0][0][1];
		x[1][1][0][0][0] = x1[1][0][0][0] + x[0][0][0][1][0];
		x[1][1][0][0][1] = x1[1][0][0][1] + x[0][0][0][1][1];
		x[1][1][1][1][0] = x1[1][1][1][0] + x[0][0][1][0][0];
		x[1][1][1][1][1] = x1[1][1][1][1] + x[0][0][1][0][1];
		x[1][1][1][0][0] = x1[1][1][0][0] + x[0][0][1][1][0];
		x[1][1][1][0][1] = x1[1][1][0][1] + x[0][0][1][1][1];
		x[1][0][0][1][0] = x1[0][0][1][0] + x[0][1][0][0][0];
		x[1][0][0][1][1] = x1[0][0][1][1] + x[0][1][0][0][1];
		x[1][0][0][0][0] = x1[0][0][0][0] + x[0][1][0][1][0];
		x[1][0][0][0][1] = x1[0][0][0][1] + x[0][1][0][1][1];
		x[1][0][1][1][0] = x1[0][1][1][0] + x[0][1][1][0][0];
		x[1][0][1][1][1] = x1[0][1][1][1] + x[0][1][1][0][1];
		x[1][0][1][0][0] = x1[0][1][0][0] + x[0][1][1][1][0];
		x[1][0][1][0][1] = x1[0][1][0][1] + x[0][1][1][1][1];

		/* "xor x_1~j~k~lm into x_0jklm" */
		x[0][0][0][0][0] = x0[0][0][0][0] ^ x[1][1][1][1][0];
		x[0][0][0][0][1] = x0[0][0][0][1] ^ x[1][1][1][1][1];
		x[0][0][0][1][0] = x0[0][0][1][0] ^ x[1][1][1][0][0];
		x[0][0][0][1][1] = x0[0][0][1][1] ^ x[1][1][1][0][1];
		x[0][0][1][0][0] = x0[0][1][0][0] ^ x[1][1][0][1][0];
		x[0][0][1][0][1] = x0[0][1][0][1] ^ x[1][1][0][1][1];
		x[0][0][1][1][0] = x0[0][1][1][0] ^ x[1][1][0][0][0];
		x[0][0][1][1][1] = x0[0][1][1][1] ^ x[1][1][0][0][1];
		x[0][1][0][0][0] = x0[1][0][0][0] ^ x[1][0][1][1][0];
		x[0][1][0][0][1] = x0[1][0][0][1] ^ x[1][0][1][1][1];
		x[0][1][0][1][0] = x0[1][0][1][0] ^ x[1][0][1][0][0];
		x[0][1][0][1][1] = x0[1][0][1][1] ^ x[1][0][1][0][1];
		x[0][1][1][0][0] = x0[1][1][0][0] ^ x[1][0][0][1][0];
		x[0][1][1][0][1] = x0[1][1][0][1] ^ x[1][0][0][1][1];
		x[0][1][1][1][0] = x0[1][1][1][0] ^ x[1][0][0][0][0];
		x[0][1][1][1][1] = x0[1][1][1][1] ^ x[1][0][0][0][1];

		/* "rotate x_0jklm upwards by 7 bits" */
		x0[0][0][0][0] = ROTATEUPWARDS7(x[0][0][0][0][0]);
		x0[0][0][0][1] = ROTATEUPWARDS7(x[0][0][0][0][1]);
		x0[0][0][1][0] = ROTATEUPWARDS7(x[0][0][0][1][0]);
		x0[0][0][1][1] = ROTATEUPWARDS7(x[0][0][0][1][1]);
		x0[0][1][0][0] = ROTATEUPWARDS7(x[0][0][1][0][0]);
		x0[0][1][0][1] = ROTATEUPWARDS7(x[0][0][1][0][1]);
		x0[0][1][1][0] = ROTATEUPWARDS7(x[0][0][1][1][0]);
		x0[0][1][1][1] = ROTATEUPWARDS7(x[0][0][1][1][1]);
		x0[1][0][0][0] = ROTATEUPWARDS7(x[0][1][0][0][0]);
		x0[1][0][0][1] = ROTATEUPWARDS7(x[0][1][0][0][1]);
		x0[1][0][1][0] = ROTATEUPWARDS7(x[0][1][0][1][0]);
		x0[1][0][1][1] = ROTATEUPWARDS7(x[0][1][0][1][1]);
		x0[1][1][0][0] = ROTATEUPWARDS7(x[0][1][1][0][0]);
		x0[1][1][0][1] = ROTATEUPWARDS7(x[0][1][1][0][1]);
		x0[1][1][1][0] = ROTATEUPWARDS7(x[0][1][1][1][0]);
		x0[1][1][1][1] = ROTATEUPWARDS7(x[0][1][1][1][1]);

		/* "add x_0jklm into x_1~j~k~l~m modulo 2^32" */
		x1[1][1][1][1] = x[1][1][1][1][1] + x[0][0][0][0][0];
		x1[1][1][1][0] = x[1][1][1][1][0] + x[0][0][0][0][1];
		x1[1][1][0][1] = x[1][1][1][0][1] + x[0][0][0][1][0];
		x1[1][1][0][0] = x[1][1][1][0][0] + x[0][0][0][1][1];
		x1[1][0][1][1] = x[1][1][0][1][1] + x[0][0][1][0][0];
		x1[1][0][1][0] = x[1][1][0][1][0] + x[0][0][1][0][1];
		x1[1][0][0][1] = x[1][1][0][0][1] + x[0][0][1][1][0];
		x1[1][0][0][0] = x[1][1][0][0][0] + x[0][0][1][1][1];
		x1[0][1][1][1] = x[1][0][1][1][1] + x[0][1][0][0][0];
		x1[0][1][1][0] = x[1][0][1][1][0] + x[0][1][0][0][1];
		x1[0][1][0][1] = x[1][0][1][0][1] + x[0][1][0][1][0];
		x1[0][1][0][0] = x[1][0][1][0][0] + x[0][1][0][1][1];
		x1[0][0][1][1] = x[1][0][0][1][1] + x[0][1][1][0][0];
		x1[0][0][1][0] = x[1][0][0][1][0] + x[0][1][1][0][1];
		x1[0][0][0][1] = x[1][0][0][0][1] + x[0][1][1][1][0];
		x1[0][0][0][0] = x[1][0][0][0][0] + x[0][1][1][1][1];

		/* "xor x_1j~k~l~m into x_0jklm" */
		x[0][0][0][0][0] = x0[0][0][0][0] ^ x1[0][1][1][1];
		x[0][0][0][0][1] = x0[0][0][0][1] ^ x1[0][1][1][0];
		x[0][0][0][1][0] = x0[0][0][1][0] ^ x1[0][1][0][1];
		x[0][0][0][1][1] = x0[0][0][1][1] ^ x1[0][1][0][0];
		x[0][0][1][0][0] = x0[0][1][0][0] ^ x1[0][0][1][1];
		x[0][0][1][0][1] = x0[0][1][0][1] ^ x1[0][0][1][0];
		x[0][0][1][1][0] = x0[0][1][1][0] ^ x1[0][0][0][1];
		x[0][0][1][1][1] = x0[0][1][1][1] ^ x1[0][0][0][0];
		x[0][1][0][0][0] = x0[1][0][0][0] ^ x1[1][1][1][1];
		x[0][1][0][0][1] = x0[1][0][0][1] ^ x1[1][1][1][0];
		x[0][1][0][1][0] = x0[1][0][1][0] ^ x1[1][1][0][1];
		x[0][1][0][1][1] = x0[1][0][1][1] ^ x1[1][1][0][0];
		x[0][1][1][0][0] = x0[1][1][0][0] ^ x1[1][0][1][1];
		x[0][1][1][0][1] = x0[1][1][0][1] ^ x1[1][0][1][0];
		x[0][1][1][1][0] = x0[1][1][1][0] ^ x1[1][0][0][1];
		x[0][1][1][1][1] = x0[1][1][1][1] ^ x1[1][0][0][0];

		/* "rotate x_0jklm upwards by 11 bits" */
		x0[0][0][0][0] = ROTATEUPWARDS11(x[0][0][0][0][0]);
		x0[0][0][0][1] = ROTATEUPWARDS11(x[0][0][0][0][1]);
		x0[0][0][1][0] = ROTATEUPWARDS11(x[0][0][0][1][0]);
		x0[0][0][1][1] = ROTATEUPWARDS11(x[0][0][0][1][1]);
		x0[0][1][0][0] = ROTATEUPWARDS11(x[0][0][1][0][0]);
		x0[0][1][0][1] = ROTATEUPWARDS11(x[0][0][1][0][1]);
		x0[0][1][1][0] = ROTATEUPWARDS11(x[0][0][1][1][0]);
		x0[0][1][1][1] = ROTATEUPWARDS11(x[0][0][1][1][1]);
		x0[1][0][0][0] = ROTATEUPWARDS11(x[0][1][0][0][0]);
		x0[1][0][0][1] = ROTATEUPWARDS11(x[0][1][0][0][1]);
		x0[1][0][1][0] = ROTATEUPWARDS11(x[0][1][0][1][0]);
		x0[1][0][1][1] = ROTATEUPWARDS11(x[0][1][0][1][1]);
		x0[1][1][0][0] = ROTATEUPWARDS11(x[0][1][1][0][0]);
		x0[1][1][0][1] = ROTATEUPWARDS11(x[0][1][1][0][1]);
		x0[1][1][1][0] = ROTATEUPWARDS11(x[0][1][1][1][0]);
		x0[1][1][1][1] = ROTATEUPWARDS11(x[0][1][1][1][1]);

		/* "add x_0jklm into x_1j~kl~m modulo 2^32" */
		x[1][0][1][0][1] = x1[0][1][0][1] + x[0][0][0][0][0];
		x[1][0][1][0][0] = x1[0][1][0][0] + x[0][0][0][0][1];
		x[1][0][1][1][1] = x1[0][1][1][1] + x[0][0][0][1][0];
		x[1][0][1][1][0] = x1[0][1][1][0] + x[0][0][0][1][1];
		x[1][0][0][0][1] = x1[0][0][0][1] + x[0][0][1][0][0];
		x[1][0][0][0][0] = x1[0][0][0][0] + x[0][0][1][0][1];
		x[1][0][0][1][1] = x1[0][0][1][1] + x[0][0][1][1][0];
		x[1][0][0][1][0] = x1[0][0][1][0] + x[0][0][1][1][1];
		x[1][1][1][0][1] = x1[1][1][0][1] + x[0][1][0][0][0];
		x[1][1][1][0][0] = x1[1][1][0][0] + x[0][1][0][0][1];
		x[1][1][1][1][1] = x1[1][1][1][1] + x[0][1][0][1][0];
		x[1][1][1][1][0] = x1[1][1][1][0] + x[0][1][0][1][1];
		x[1][1][0][0][1] = x1[1][0][0][1] + x[0][1][1][0][0];
		x[1][1][0][0][0] = x1[1][0][0][0] + x[0][1][1][0][1];
		x[1][1][0][1][1] = x1[1][0][1][1] + x[0][1][1][1][0];
		x[1][1][0][1][0] = x1[1][0][1][0] + x[0][1][1][1][1];

		/* "xor x_1jkl~m into x_0jklm" */
		x[0][0][0][0][0] = x0[0][0][0][0] ^ x[1][0][0][0][1];
		x[0][0][0][0][1] = x0[0][0][0][1] ^ x[1][0][0][0][0];
		x[0][0][0][1][0] = x0[0][0][1][0] ^ x[1][0][0][1][1];
		x[0][0][0][1][1] = x0[0][0][1][1] ^ x[1][0][0][1][0];
		x[0][0][1][0][0] = x0[0][1][0][0] ^ x[1][0][1][0][1];
		x[0][0][1][0][1] = x0[0][1][0][1] ^ x[1][0][1][0][0];
		x[0][0][1][1][0] = x0[0][1][1][0] ^ x[1][0][1][1][1];
		x[0][0][1][1][1] = x0[0][1][1][1] ^ x[1][0][1][1][0];
		x[0][1][0][0][0] = x0[1][0][0][0] ^ x[1][1][0][0][1];
		x[0][1][0][0][1] = x0[1][0][0][1] ^ x[1][1][0][0][0];
		x[0][1][0][1][0] = x0[1][0][1][0] ^ x[1][1][0][1][1];
		x[0][1][0][1][1] = x0[1][0][1][1] ^ x[1][1][0][1][0];
		x[0][1][1][0][0] = x0[1][1][0][0] ^ x[1][1][1][0][1];
		x[0][1][1][0][1] = x0[1][1][0][1] ^ x[1][1][1][0][0];
		x[0][1][1][1][0] = x0[1][1][1][0] ^ x[1][1][1][1][1];
		x[0][1][1][1][1] = x0[1][1][1][1] ^ x[1][1][1][1][0];
	}
}

__device__ __forceinline__
void Final(uint32_t x[2][2][2][2][2], uint32_t *hashval)
{
	/* "the integer 1 is xored into the last state word x_11111" */
	x[1][1][1][1][1] ^= 1U;

	/* "the state is then transformed invertibly through 10r identical rounds" */
	for (int i = 0; i < 10; ++i) rrounds(x);

	/* "output the first h/8 bytes of the state" */
	hashval[0] = x[0][0][0][0][0];
	hashval[1] = x[0][0][0][0][1];
	hashval[2] = x[0][0][0][1][0];
	hashval[3] = x[0][0][0][1][1];
	hashval[4] = x[0][0][1][0][0];
	hashval[5] = x[0][0][1][0][1];
	hashval[6] = x[0][0][1][1][0];
	hashval[7] = x[0][0][1][1][1];
}

#if __CUDA_ARCH__ >= 500
__global__ __launch_bounds__(TPB50, 1)
#else
__global__ __launch_bounds__(TPB35, 1)
#endif
void cubehash256_gpu_hash_32(uint32_t threads, uint32_t startNounce, uint2 *g_hash)
{
	uint32_t thread = (blockDim.x * blockIdx.x + threadIdx.x);
	if (thread < threads)
	{
#if __CUDA_ARCH__ >= 500
		uint2 Hash[4];

		Hash[0] = __ldg(&g_hash[thread]);
		Hash[1] = __ldg(&g_hash[thread + 1 * threads]);
		Hash[2] = __ldg(&g_hash[thread + 2 * threads]);
		Hash[3] = __ldg(&g_hash[thread + 3 * threads]);
#else
		uint32_t Hash[8];

		LOHI(Hash[0], Hash[1], __ldg(&((uint64_t*)g_hash)[thread]));
		LOHI(Hash[2], Hash[3], __ldg(&((uint64_t*)g_hash)[thread + 1 * threads]));
		LOHI(Hash[4], Hash[5], __ldg(&((uint64_t*)g_hash)[thread + 2 * threads]));
		LOHI(Hash[6], Hash[7], __ldg(&((uint64_t*)g_hash)[thread + 3 * threads]));
#endif

		uint32_t x[2][2][2][2][2] =
		{
			0xEA2BD4B4, 0xCCD6F29F, 0x63117E71, 0x35481EAE,
			0x22512D5B, 0xE5D94E63, 0x7E624131, 0xF4CC12BE,
			0xC2D0B696, 0x42AF2070, 0xD0720C35, 0x3361DA8C,
			0x28CCECA4, 0x8EF8AD83, 0x4680AC00, 0x40E5FBAB,
			0xD89041C3, 0x6107FBD5, 0x6C859D41, 0xF0B26679,
			0x09392549, 0x5FA25603, 0x65C892FD, 0x93CB6285,
			0x2AF2B5AE, 0x9E4B4E60, 0x774ABFDD, 0x85254725,
			0x15815AEB, 0x4AB6AAD6, 0x9CDAF8AF, 0xD6032C0A
		};

#if __CUDA_ARCH__ >= 500
		x[0][0][0][0][0] ^= Hash[0].x;
		x[0][0][0][0][1] ^= Hash[0].y;
		x[0][0][0][1][0] ^= Hash[1].x;
		x[0][0][0][1][1] ^= Hash[1].y;
		x[0][0][1][0][0] ^= Hash[2].x;
		x[0][0][1][0][1] ^= Hash[2].y;
		x[0][0][1][1][0] ^= Hash[3].x;
		x[0][0][1][1][1] ^= Hash[3].y;
#else
		x[0][0][0][0][0] ^= Hash[0];
		x[0][0][0][0][1] ^= Hash[1];
		x[0][0][0][1][0] ^= Hash[2];
		x[0][0][0][1][1] ^= Hash[3];
		x[0][0][1][0][0] ^= Hash[4];
		x[0][0][1][0][1] ^= Hash[5];
		x[0][0][1][1][0] ^= Hash[6];
		x[0][0][1][1][1] ^= Hash[7];
#endif
		rrounds(x);
		x[0][0][0][0][0] ^= 0x80U;
		rrounds(x);

#if __CUDA_ARCH__ >= 500
		Final(x, (uint32_t*)Hash);

		g_hash[thread] = Hash[0];
		g_hash[1 * threads + thread] = Hash[1];
		g_hash[2 * threads + thread] = Hash[2];
		g_hash[3 * threads + thread] = Hash[3];
#else
		Final(x, Hash);

		((uint64_t*)g_hash)[thread] = ((uint64_t*)Hash)[0];
		((uint64_t*)g_hash)[1 * threads + thread] = ((uint64_t*)Hash)[1];
		((uint64_t*)g_hash)[2 * threads + thread] = ((uint64_t*)Hash)[2];
		((uint64_t*)g_hash)[3 * threads + thread] = ((uint64_t*)Hash)[3];
#endif
	}
}

__host__
void cubehash256_cpu_hash_32(int thr_id, uint32_t threads, uint32_t startNounce, uint64_t *d_hash, int order)
{
	uint32_t tpb = TPB35;
	if (cuda_arch[thr_id] >= 500) tpb = TPB50;

	dim3 grid((threads + tpb - 1) / tpb);
	dim3 block(tpb);

	cubehash256_gpu_hash_32 <<<grid, block >>> (threads, startNounce, (uint2*)d_hash);
}

__host__
void cubehash256_cpu_hash_32(int thr_id, uint32_t threads, uint32_t startNounce, uint64_t *d_hash, int order, cudaStream_t stream)
{
	uint32_t tpb = TPB35;
	if (cuda_arch[thr_id] >= 500) tpb = TPB50;

	dim3 grid((threads + tpb - 1) / tpb);
	dim3 block(tpb);

	cubehash256_gpu_hash_32 <<<grid, block, 0, stream >>> (threads, startNounce, (uint2*)d_hash);
}
