package away3d.core.raycast.colliders.triangles
{

	import away3d.core.raycast.data.RayCollisionVO;

	import flash.geom.Point;
	import flash.geom.Vector3D;

	public class AS3SubMeshRayCollider extends SubMeshRayColliderBase
	{
		// TODO: implement find best hit

		public function AS3SubMeshRayCollider( findBestHit:Boolean ) {
			super( findBestHit );
		}

		override public function evaluate():void {

			reset();

			var i:uint;
			var t:Number;
			var numTriangles:uint;
			var i0:uint, i1:uint, i2:uint;
			var rx:Number, ry:Number, rz:Number;
			var nx:Number, ny:Number, nz:Number;
			var cx:Number, cy:Number, cz:Number;
			var coeff:Number, v:Number, w:Number;
			var p0x:Number, p0y:Number, p0z:Number;
			var p1x:Number, p1y:Number, p1z:Number;
			var p2x:Number, p2y:Number, p2z:Number;
			var s0x:Number, s0y:Number, s0z:Number;
			var s1x:Number, s1y:Number, s1z:Number;
			var nl:Number, nDotV:Number, D:Number, disToPlane:Number;
			var Q1Q2:Number, Q1Q1:Number, Q2Q2:Number, RQ1:Number, RQ2:Number;

			_indexData = _subMesh.indexData;
			_vertexData = _subMesh.vertexData;
			_uvData = _subMesh.UVData;
			numTriangles = _subMesh.numTriangles;

			for( i = 0; i < numTriangles; ++i ) { // sweep all triangles

				var index:uint = i * 3;

				// evaluate triangle indices
				i0 = _indexData[ index ] * 3;
				i1 = _indexData[ index + 1 ] * 3;
				i2 = _indexData[ index + 2 ] * 3;

				// evaluate triangle vertices
				p0x = _vertexData[ i0 ];
				p0y = _vertexData[ i0 + 1 ];
				p0z = _vertexData[ i0 + 2 ];
				p1x = _vertexData[ i1 ];
				p1y = _vertexData[ i1 + 1 ];
				p1z = _vertexData[ i1 + 2 ];
				p2x = _vertexData[ i2 ];
				p2y = _vertexData[ i2 + 1 ];
				p2z = _vertexData[ i2 + 2 ];

				// evaluate sides and triangle normal
				s0x = p1x - p0x; // s0 = p1 - p0
				s0y = p1y - p0y;
				s0z = p1z - p0z;
				s1x = p2x - p0x; // s1 = p2 - p0
				s1y = p2y - p0y;
				s1z = p2z - p0z;
				nx = s0y * s1z - s0z * s1y; // n = s0 x s1
				ny = s0z * s1x - s0x * s1z;
				nz = s0x * s1y - s0y * s1x;
				nl = 1 / Math.sqrt( nx * nx + ny * ny + nz * nz ); // normalize n
				nx *= nl;
				ny *= nl;
				nz *= nl;

				// -- plane intersection test --
				nDotV = nx * _rayDirection.x + ny * + _rayDirection.y + nz * _rayDirection.z; // rayDirection . normal
				if( nDotV < 0 ) { // an intersection must exist
					// find collision t
					D = -( nx * p0x + ny * p0y + nz * p0z );
					disToPlane = -( nx * _rayPosition.x + ny * _rayPosition.y + nz * _rayPosition.z + D );
					t = disToPlane / nDotV;
					// find collision point
					cx = _rayPosition.x + t * _rayDirection.x;
					cy = _rayPosition.y + t * _rayDirection.y;
					cz = _rayPosition.z + t * _rayDirection.z;
					// collision point inside triangle? ( using barycentric coordinates )
					Q1Q2 = s0x * s1x + s0y * s1y + s0z * s1z;
					Q1Q1 = s0x * s0x + s0y * s0y + s0z * s0z;
					Q2Q2 = s1x * s1x + s1y * s1y + s1z * s1z;
					rx = cx - p0x;
					ry = cy - p0y;
					rz = cz - p0z;
					RQ1 = rx * s0x + ry * s0y + rz * s0z;
					RQ2 = rx * s1x + ry * s1y + rz * s1z;
					coeff = 1 / ( Q1Q1 * Q2Q2 - Q1Q2 * Q1Q2 );
					v = coeff * ( Q2Q2 * RQ1 - Q1Q2 * RQ2 );
					w = coeff * ( -Q1Q2 * RQ1 + Q1Q1 * RQ2 );
					if( v < 0 ) continue;
					if( w < 0 ) continue;
					var u:Number = 1 - v - w;
					if( !( u < 0 ) ) { // all tests passed
						_collisionData = new RayCollisionVO();
						_collisionData.t = t;
						_collisionData.localRayPosition = _rayPosition;
						_collisionData.localRayDirection = _rayDirection;
						_collisionData.position = new Vector3D( cx, cy, cz );
						_collisionData.normal = new Vector3D( nx, ny, nz );
						_collisionData.uv = getCollisionUV( index, v, w, u );
						_collides = true; // does not search for closest collision, first found will do... // TODO: add option of finding best triangle hit?
						return;
					}
				}
			}
		}

		private function getCollisionUV( triangleIndex:uint, v:Number, w:Number, u:Number ):Point {
			var uv:Point = new Point();
			var uvIndex:Number = _indexData[ triangleIndex ] * 2;
			var uv0:Vector3D = new Vector3D( _uvData[ uvIndex ], _uvData[ uvIndex + 1 ] );
			triangleIndex++;
			uvIndex = _indexData[ triangleIndex ] * 2;
			var uv1:Vector3D = new Vector3D( _uvData[ uvIndex ], _uvData[ uvIndex + 1 ] );
			triangleIndex++;
			uvIndex = _indexData[ triangleIndex ] * 2;
			var uv2:Vector3D = new Vector3D( _uvData[ uvIndex ], _uvData[ uvIndex + 1 ] );
			uv.x = u * uv0.x + v * uv1.x + w * uv2.x;
			uv.y = u * uv0.y + v * uv1.y + w * uv2.y;
			return uv;
		}
	}
}
