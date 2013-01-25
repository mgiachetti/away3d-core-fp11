package away3d.loaders.parsers
{
	import away3d.animators.VertexAnimator;
	import away3d.animators.data.VertexAnimationMode;
	import away3d.arcane;
	import away3d.core.base.Geometry;
	import away3d.core.base.SubGeometry;
	import away3d.entities.Mesh;
	import away3d.loaders.misc.ResourceDependency;
	import away3d.materials.ColorMaterial;
	import away3d.materials.MaterialBase;
	import away3d.materials.TextureMaterial;
	import away3d.materials.lightpickers.StaticLightPicker;
	import away3d.materials.utils.DefaultMaterialManager;
	import away3d.textures.BitmapTexture;
	import away3d.textures.Texture2DBase;
	
	import com.mgsoft.mg3dengine.FilePath;
	import com.mgsoft.mg3dengine.MG3DGlobals;
	import com.mgsoft.mg3dengine.MGColorUtils;
	import com.mgsoft.mg3dengine.MGMaterial;
	import com.mgsoft.mg3dengine.MGTexturePool;
	
	import flash.net.FileReference;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Endian;

	use namespace arcane;
	
	/**
	 * MD2Parser provides a parser for the MD2 data type.
	 */
	public class YParser extends ParserBase
	{
		private var _byteData : ByteArray;
		private var _startedParsing : Boolean;
		private var _parsedHeader : Boolean;
		private var _parsedLayers : Boolean;
		private var _parsedVertices : Boolean;
		private var _parsedIndices : Boolean;
		private var _parsedAtributos : Boolean;
		private var _createMesh : Boolean;
		
		private var _vertices : Vector.<Number>;
		private var _normals : Vector.<Number>;
		private var _uvs : Vector.<Number>;
		private var _indices : Vector.<uint>;
		private var _atributos : Vector.<uint>;
		
		private var _materialNames : Vector.<String>;
		private var _materialData : Vector.<MGMaterial>;
		private var _mesh : Mesh;
		private var _geometry : Geometry;
		
		//mis variables
		private var _cant_layers : int;
		private var _cant_faces : int;
		private var _sizeof_vertex : int;
		private var _cant_vertices : int;
		private var _id_subgeometry: Vector.<int> = new Vector.<int>();
		
		
		/**
		 * Creates a new MD2Parser object.
		 * @param uri The url or id of the data or file to be parsed.
		 * @param extra The holder for extra contextual data that the parser might need.
		 */
		public function YParser()
		{
			super(ParserDataFormat.BINARY);
		}
		
		/**
		 * Indicates whether or not a given file extension is supported by the parser.
		 * @param extension The file extension of a potential file to be parsed.
		 * @return Whether or not the given file type is supported.
		 */
		public static function supportsType(extension : String) : Boolean
		{
			extension = extension.toLowerCase();
			return extension == "y";
		}
		
		/**
		 * Tests whether a data block can be parsed by the parser.
		 * @param data The data block to potentially be parsed.
		 * @return Whether or not the given data is supported.
		 */
		public static function supportsData(data : *) : Boolean
		{
			// TODO: not used
			data = data;
			// todo: implement
			return false;
		}
		
		/**
		 * @inheritDoc
		 */
		override arcane function resolveDependency(resourceDependency : ResourceDependency) : void
		{
			if (resourceDependency.assets.length != 1)
				return;
			
			for (var i:int = 0; i < _mesh.subMeshes.length; i++) 
			{
				var nro_layer : int = _id_subgeometry[i];
				if(_materialNames[nro_layer] == resourceDependency.id)
				{
					var asset : Texture2DBase = resourceDependency.assets[0] as Texture2DBase;
					if (asset)
					{
						//_mesh.subMeshes[i].material = new TextureMaterial(asset, true, true);
						(_mesh.subMeshes[i].material as TextureMaterial).texture = asset;
						_mesh.subMeshes[i].material.bothSides = true;
					}
					
				}
				
			}
			
		}
		/**
		 * @inheritDoc
		 */
		override arcane function resolveDependencyFailure(resourceDependency:ResourceDependency):void
		{
			// TODO: not used
			resourceDependency = resourceDependency; 			
			// apply system default
			TextureMaterial(_mesh.material).texture = DefaultMaterialManager.getDefaultTexture();
		} 
		
		
		/**
		 * @inheritDoc
		 */
		protected override function proceedParsing() : Boolean
		{
			if(!_startedParsing) {
				_byteData = getByteData();
				_startedParsing = true;
				//(new FileReference()).save(_byteData,FilePath.GetFileName(_fileName));
				//return true;
			}
			
			try
			{
				while (hasTime()) {
					if (!_parsedHeader) {
						_byteData.endian = Endian.LITTLE_ENDIAN;
						
						// TODO: Create a mesh only when encountered (if it makes sense
						// for this file format) and return it using finalizeAsset()
						_mesh = new Mesh(new Geometry());
						_mesh.material = new TextureMaterial( DefaultMaterialManager.getDefaultTexture() );
						_mesh.material.bothSides = true;
						
						_geometry = _mesh.geometry;
						
						// Parse header and decompress body
						parseHeader();
					}
						
					else {
						if (!_parsedLayers) {
							parseLayers();
						}
							
						else {
							if (!_parsedVertices) {
								parseVertices();
							}
								
							else {
								if (!_parsedIndices) {
									parseIndices();
								}
								else
								{
									if(!_parsedAtributos){
										parsedAtributos();
										
									}									
									else {
										
										buildMesh();
										finalizeAsset(_mesh, _fileName);
										return true;
									}								
								}								
								
							}
						}
					}
				}
			}
			catch(e : Error)
			{
				trace("Error con mesh "+ _fileName);
				return true;
			}
			
			
			return false;
		}
		
		private function buildMesh():void
		{
			var offsetMat : int = 0;
			for (var i:int = 0; i < _cant_layers; i++) 
			{
				
				var indices: Vector.<uint> = new Vector.<uint>();
				var vertTable: Vector.<uint> = new Vector.<uint>(_vertices.length/3);
				var vertList: Vector.<uint> = new Vector.<uint>();
				var addLayer: Boolean = false;
				
				//si un mesh tiene mas de 65000 vertices esos vertices tinene que estar distribuidos en distintos subset
				//reubico los vertices para que se puedan poner hasta 65000 vertices por subset
				
				for (var j:int = 0; j < _cant_faces; j++) 
				{
					if (_atributos[j] == i)
					{
						if(indices.length < 65500)
						{
							for (var i2:int = 0; i2 < 3; i2++) 
							{
								var ind : uint = _indices[j*3 + i2];
								
								if(vertTable[ind] == 0)
								{
									vertList.push(ind);
									vertTable[ind] = vertList.length;
								}
								
								indices.push(vertTable[ind] - 1);
							}
						}
						else
						{
							//como no entra en el vertex buffer lo parto en 2 y agrego otro subset
							_atributos[j]= _cant_layers;
							addLayer = true;
						}
					}
				}
				
				offsetMat = 0;
				var nro_mat : int = i + offsetMat;
				if(addLayer)
				{
					_cant_layers++;
					
					_materialNames.push(_materialNames[nro_mat]);
					_materialData.push(_materialData[nro_mat]);
					
					_materialNames[_cant_layers+offsetMat-1] = _materialNames[nro_mat];
					_materialData[_cant_layers+offsetMat-1] = _materialData[nro_mat];
				}
				
				if(indices.length <= 0)
				{
					if(_geometry.subGeometries.length == 0)
						offsetMat--;
					continue;
				}
				
				var vertices : Vector.<Number> = new Vector.<Number>();
				var uvs : Vector.<Number> = new Vector.<Number>();
				var normals : Vector.<Number> = new Vector.<Number>();

				for (var k:int = 0; k < vertList.length; k++) 
				{
					ind = vertList[k];
					vertices.push(_vertices[ind*3],_vertices[ind*3+1],_vertices[ind*3+2]);
					uvs.push(_uvs[ind*2],_uvs[ind*2+1]);
					normals.push(_normals[ind*3],_normals[ind*3+1],_normals[ind*3+2]);
				}
				
				
				//guardo el id para poder identificar el nro_layer con el nro se subgeometry
				_id_subgeometry.push(nro_mat);
				
				var sub : SubGeometry = new SubGeometry();
				
				_geometry.addSubGeometry(sub);
				//sub.updateVertexData(_vertices);
				//sub.updateUVData(_uvs);
				//sub.updateVertexNormalData(_normals);
				sub.updateVertexData(vertices);
				sub.updateUVData(uvs);
				sub.updateVertexNormalData(normals);
				sub.updateIndexData(indices);
				
				trace("Subset = "+i+" cant_vert = "+vertices.length);
				
				var mat : MaterialBase;
				
				if(FilePath.GetFileNameWithoutExtension(_materialNames[nro_mat]) != "")
					//este layer tiene una texturaa
					mat = MGTexturePool.getTexture(_materialNames[nro_mat]);// new TextureMaterial(null, true, true);
				else
				{
					//Este layer tiene un color
					mat = new ColorMaterial(_materialData[nro_mat].Diffuse,MGColorUtils.getA(_materialData[nro_mat].Diffuse)/255);
				}
				
				//mat.lightPicker = new StaticLightPicker(MG3DGlobals.lights);
				
				_mesh.subMeshes[_geometry.subGeometries.length - 1].material = mat;
				_mesh.subMeshes[_geometry.subGeometries.length - 1].material.bothSides = true;
				sub.nroLayer = nro_mat;
			}
			
			//le agrego un padre para que no lo dibuje en pantalla con la posicion 0,0,0
			_mesh.setParent(new Mesh(new Geometry()));
			
			_createMesh = true;
		}
		
		private function parsedAtributos():void
		{
			_atributos = new Vector.<uint>();
			
			var cant_atrib:int = _cant_faces;
			
			for (var i:int = 0; i < cant_atrib; i++)
			{
				if(_byteData.bytesAvailable >= 4)
				{
					_atributos.push(_byteData.readInt());
				}
				else
				{
					_atributos.push(_atributos[_atributos.length-1]);
				}
					
			}
			
			_parsedAtributos = true;			
		}
		
		private function parseIndices():void
		{
			_indices = new Vector.<uint>();
			
			var cant_indices:int = _cant_faces * 3;
			var i:int;
			
			if(_byteData.length - _byteData.position < cant_indices*4)
			{
				//es un mesh sin la informacion de los indices
				for (i = 0; i < cant_indices; i++)
				{
					_indices.push(i);
				}
			}
			else
			{
				for (i = 0; i < cant_indices; i++)
				{
					_indices.push(_byteData.readInt());
				}
			}

			_parsedIndices = true;
		}
		
		private function parseVertices():void
		{
			_vertices = new Vector.<Number>();
			_normals = new Vector.<Number>();
			_uvs = new Vector.<Number>();
			
			//numero de faces
			_cant_faces = _byteData.readInt();
			
			//vertices
			_cant_vertices = _byteData.readInt();//_cant_faces*3;
			
			//bytes por vertice
			_sizeof_vertex = _byteData.readInt();
						
			for (var i:int = 0; i < _cant_vertices; i++)
			{
				var x:Number = _byteData.readFloat();
				var z:Number = _byteData.readFloat();
				var y:Number = _byteData.readFloat();				
				//_vertices.push(new Vertex(x, y, z));
				_vertices.push(x);
				_vertices.push(y);
				_vertices.push(-z);
				
				x = _byteData.readFloat();
				z = _byteData.readFloat();
				y = _byteData.readFloat();				
				//_normals.push(new Vertex(x, y, z));
				_normals.push(x);
				_normals.push(y);
				_normals.push(-z);
				
				if(_sizeof_vertex >= 32)
				{
					var u:Number = _byteData.readFloat();
					var v:Number = _byteData.readFloat();
					//_uvs.push(new UV(u, v));
					_uvs.push(u);
					_uvs.push(v);
				}else
				{
					_uvs.push(0.0);
					_uvs.push(0.0);
				}
				
				if(_sizeof_vertex > 32)
					_byteData.position = _byteData.position + _sizeof_vertex - 32;
			}
			
			_parsedVertices = true;

		}
		
		private function parseLayers():void
		{
			var url : String;
			var name : String;
			_materialNames = new Vector.<String>();
			_materialData = new Vector.<MGMaterial>();
			
			//cantidad de layers
			_cant_layers = _byteData.readInt();
			trace("Mesh:" + _fileName +" cant_layers = "+_cant_layers);
			for (var i:int = 0; i < _cant_layers; i++)
			{
				//nombre de la textura
				
				name = _byteData.readUTFBytes(256);
				//name = name.substring(0, name.search('\0'));
				url = MG3DGlobals.TEXTURE_FOLDER + name;
				//url = "http://www.lepton.com.ar/download/armarius/texturas/05-nogal.jpg";
				//url = "http://www.lepton.com.ar/download/armarius/texturas/05-nogal.bmp";
				
				//_materialNames[i] = name;
				_materialNames[i] = url;
				
				//if(name != "")
					//addDependency(name, new URLRequest(url));
				
				//material
				var mat : MGMaterial = new MGMaterial();
				mat.Diffuse = MGColorUtils.colorFromARGB(_byteData.readFloat()*255,_byteData.readFloat()*255,_byteData.readFloat()*255,_byteData.readFloat()*255);
				mat.Ambient = MGColorUtils.colorFromARGB(_byteData.readFloat()*255,_byteData.readFloat()*255,_byteData.readFloat()*255,_byteData.readFloat()*255);
				mat.Specular = MGColorUtils.colorFromARGB(_byteData.readFloat()*255,_byteData.readFloat()*255,_byteData.readFloat()*255,_byteData.readFloat()*255);
				mat.Emissive = MGColorUtils.colorFromARGB(_byteData.readFloat()*255,_byteData.readFloat()*255,_byteData.readFloat()*255,_byteData.readFloat()*255);
				mat.Power = _byteData.readFloat();
				
				_materialData[i] = mat;
				
				//leo 17 floats del material del subset
				//_byteData.readBytes(new ByteArray(), 0, 17*4);
				
			}
			
			_parsedLayers = true;
		}
		
		/**
		 * Reads in all that MD2 Header data that is declared as private variables.
		 * I know its a lot, and it looks ugly, but only way to do it in Flash
		 */
		private function parseHeader() : void
		{
			var header: Vector.<int> = new Vector.<int>(9);
			for (var i:int = 0; i < header.length; i++) 
			{
				header[i] = _byteData.readInt();
			}
			
			var version:int = header[6];	
			
			_parsedHeader = true;
		}
		
	}
}

