#[compute]
#version 460

struct Triangle {
	vec4 a;
	vec4 b;
	vec4 c;
	vec4 norm;
};

// #------ Marching Cubes ------#
const int cornerIndexAFromEdge[12] = {0, 1, 2, 3, 4, 5, 6, 7, 0, 1, 2, 3};
const int cornerIndexBFromEdge[12] = {1, 2, 3, 0, 5, 6, 7, 4, 4, 5, 6, 7};

const int offsets[256] = {0, 0, 3, 6, 12, 15, 21, 27, 36, 39, 45, 51, 60, 66, 75, 84, 90, 93, 99, 105, 114, 120, 129, 138, 150, 156, 165, 174, 186, 195, 207, 219, 228, 231, 237, 243, 252, 258, 267, 276, 288, 294, 303, 312, 324, 333, 345, 357, 366, 372, 381, 390, 396, 405, 417, 429, 438, 447, 459, 471, 480, 492, 507, 522, 528, 531, 537, 543, 552, 558, 567, 576, 588, 594, 603, 612, 624, 633, 645, 657, 666, 672, 681, 690, 702, 711, 723, 735, 750, 759, 771, 783, 798, 810, 825, 840, 852, 858, 867, 876, 888, 897, 909, 915, 924, 933, 945, 957, 972, 984, 999, 1008, 1014, 1023, 1035, 1047, 1056, 1068, 1083, 1092, 1098, 1110, 1125, 1140, 1152, 1167, 1173, 1185, 1188, 1191, 1197, 1203, 1212, 1218, 1227, 1236, 1248, 1254, 1263, 1272, 1284, 1293, 1305, 1317, 1326, 1332, 1341, 1350, 1362, 1371, 1383, 1395, 1410, 1419, 1425, 1437, 1446, 1458, 1467, 1482, 1488, 1494, 1503, 1512, 1524, 1533, 1545, 1557, 1572, 1581, 1593, 1605, 1620, 1632, 1647, 1662, 1674, 1683, 1695, 1707, 1716, 1728, 1743, 1758, 1770, 1782, 1791, 1806, 1812, 1827, 1839, 1845, 1848, 1854, 1863, 1872, 1884, 1893, 1905, 1917, 1932, 1941, 1953, 1965, 1980, 1986, 1995, 2004, 2010, 2019, 2031, 2043, 2058, 2070, 2085, 2100, 2106, 2118, 2127, 2142, 2154, 2163, 2169, 2181, 2184, 2193, 2205, 2217, 2232, 2244, 2259, 2268, 2280, 2292, 2307, 2322, 2328, 2337, 2349, 2355, 2358, 2364, 2373, 2382, 2388, 2397, 2409, 2415, 2418, 2427, 2433, 2445, 2448, 2454, 2457, 2460};
const int lengths[256] = {0, 3, 3, 6, 3, 6, 6, 9, 3, 6, 6, 9, 6, 9, 9, 6, 3, 6, 6, 9, 6, 9, 9, 12, 6, 9, 9, 12, 9, 12, 12, 9, 3, 6, 6, 9, 6, 9, 9, 12, 6, 9, 9, 12, 9, 12, 12, 9, 6, 9, 9, 6, 9, 12, 12, 9, 9, 12, 12, 9, 12, 15, 15, 6, 3, 6, 6, 9, 6, 9, 9, 12, 6, 9, 9, 12, 9, 12, 12, 9, 6, 9, 9, 12, 9, 12, 12, 15, 9, 12, 12, 15, 12, 15, 15, 12, 6, 9, 9, 12, 9, 12, 6, 9, 9, 12, 12, 15, 12, 15, 9, 6, 9, 12, 12, 9, 12, 15, 9, 6, 12, 15, 15, 12, 15, 6, 12, 3, 3, 6, 6, 9, 6, 9, 9, 12, 6, 9, 9, 12, 9, 12, 12, 9, 6, 9, 9, 12, 9, 12, 12, 15, 9, 6, 12, 9, 12, 9, 15, 6, 6, 9, 9, 12, 9, 12, 12, 15, 9, 12, 12, 15, 12, 15, 15, 12, 9, 12, 12, 9, 12, 15, 15, 12, 12, 9, 15, 6, 15, 12, 6, 3, 6, 9, 9, 12, 9, 12, 12, 15, 9, 12, 12, 15, 6, 9, 9, 6, 9, 12, 12, 15, 12, 15, 15, 6, 12, 9, 15, 12, 9, 6, 12, 3, 9, 12, 12, 15, 12, 15, 9, 12, 12, 15, 15, 6, 9, 12, 6, 3, 6, 9, 9, 6, 9, 12, 6, 3, 9, 6, 12, 3, 6, 3, 3, 0};

layout(set = 0, binding = 0, std430) restrict buffer TriangleBuffer
{
	Triangle data[];
}
triangleBuffer;

layout(set = 0, binding = 1, std430) restrict buffer ParamsBuffer
{
	float time;
	float noiseScale;
	float isoLevel;
	float numVoxelsPerAxis;
	float scale;
	float posX;
	float posY;
	float posZ;
	float noiseOffsetX;
	float noiseOffsetY;
	float noiseOffsetZ;
}
params;

layout(set = 0, binding = 2, std430) coherent buffer Counter
{
	uint counter;
};

layout(set = 0, binding = 3, std430) restrict buffer LutBuffer
{
	int data[];
}
lut;

layout(set = 0, binding = 4) uniform sampler2D HeightMap;


vec4 evaluate(vec3 coord)
{
	float cellSize = 1.0 / params.numVoxelsPerAxis * params.scale;
	float cx = int(params.posX / cellSize + 0.5 * sign(params.posX)) * cellSize;
	float cy = int(params.posY / cellSize + 0.5 * sign(params.posY)) * cellSize;
	float cz = int(params.posZ / cellSize + 0.5 * sign(params.posZ)) * cellSize;
	vec3 centreSnapped = vec3(cx, cy, cz);

	vec3 posNorm = coord / vec3(params.numVoxelsPerAxis) - vec3(0.5);
	vec3 worldPos = posNorm * params.scale + centreSnapped;
	vec3 noiseOffset = vec3(params.noiseOffsetX, params.noiseOffsetY, params.noiseOffsetZ);
	vec3 samplePos = (worldPos + noiseOffset) * params.noiseScale / params.scale;

	float sum = 0;
	float amplitude = 1;
	float weight = 1;
	
	float height = texture(HeightMap, samplePos.xy).r * 20.0;

	// if the voxel is below the heightmap, set density to 1
	if (worldPos.y < height) {
		return vec4(worldPos, 1);
	}
	return vec4(worldPos, -1);

	//float density = sum;
	//density = -(worldPos.y+100)/300 + density;

	//return vec4(worldPos, density);
}

vec4 interpolateVerts(vec4 v1, vec4 v2, float isoLevel)
{
	//return (v1 + v2) * 0.5;
	float t = (isoLevel - v1.w) / (v2.w - v1.w);
	return v1 + t * (v2 - v1);
}


layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;
void main()
{
	vec3 id = gl_GlobalInvocationID;

	// 8 corners of the current cube
	vec4 cubeCorners[8] = {
		evaluate(vec3(id.x + 0, id.y + 0, id.z + 0)),
		evaluate(vec3(id.x + 1, id.y + 0, id.z + 0)),
		evaluate(vec3(id.x + 1, id.y + 0, id.z + 1)),
		evaluate(vec3(id.x + 0, id.y + 0, id.z + 1)),
		evaluate(vec3(id.x + 0, id.y + 1, id.z + 0)),
		evaluate(vec3(id.x + 1, id.y + 1, id.z + 0)),
		evaluate(vec3(id.x + 1, id.y + 1, id.z + 1)),
		evaluate(vec3(id.x + 0, id.y + 1, id.z + 1))
	};

	// Calculate unique index for each cube configuration.
	// There are 256 possible values
	// A value of 0 means cube is entirely inside surface; 255 entirely outside.
	// The value is used to look up the edge table, which indicates which edges of the cube are cut by the isosurface.
	uint cubeIndex = 0;
	float isoLevel = params.isoLevel;
	if (cubeCorners[0].w < isoLevel) cubeIndex |= 1;
	if (cubeCorners[1].w < isoLevel) cubeIndex |= 2;
	if (cubeCorners[2].w < isoLevel) cubeIndex |= 4;
	if (cubeCorners[3].w < isoLevel) cubeIndex |= 8;
	if (cubeCorners[4].w < isoLevel) cubeIndex |= 16;
	if (cubeCorners[5].w < isoLevel) cubeIndex |= 32;
	if (cubeCorners[6].w < isoLevel) cubeIndex |= 64;
	if (cubeCorners[7].w < isoLevel) cubeIndex |= 128;

	// Create triangles for current cube configuration
	int numIndices = lengths[cubeIndex];
	int offset = offsets[cubeIndex];
	
	for (int i = 0; i < numIndices; i += 3) {
		// Get indices of corner points A and B for each of the three edges
		// of the cube that need to be joined to form the triangle.
		int v0 = lut.data[offset + i];
		int v1 = lut.data[offset + 1 + i];
		int v2 = lut.data[offset + 2 + i];

		int a0 = cornerIndexAFromEdge[v0];
		int b0 = cornerIndexBFromEdge[v0];

		int a1 = cornerIndexAFromEdge[v1];
		int b1 = cornerIndexBFromEdge[v1];

		int a2 = cornerIndexAFromEdge[v2];
		int b2 = cornerIndexBFromEdge[v2];

		
		// Calculate vertex positions
		Triangle currTri;
		currTri.a = interpolateVerts(cubeCorners[a0], cubeCorners[b0], isoLevel);
		currTri.b = interpolateVerts(cubeCorners[a1], cubeCorners[b1], isoLevel);
		currTri.c = interpolateVerts(cubeCorners[a2], cubeCorners[b2], isoLevel);

		vec3 ab = currTri.b.xyz - currTri.a.xyz;
		vec3 ac = currTri.c.xyz - currTri.a.xyz;
		currTri.norm = -vec4(normalize(cross(ab,ac)), 0);

		uint index = atomicAdd(counter, 1u);
		triangleBuffer.data[index] = currTri;
		
	}
}