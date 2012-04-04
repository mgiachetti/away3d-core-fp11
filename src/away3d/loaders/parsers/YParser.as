package away3d.loaders.parsers
{
	import away3d.animators.VertexAnimator;
	import away3d.animators.data.VertexAnimation;
	import away3d.animators.data.VertexAnimationMode;
	import away3d.animators.data.VertexAnimationState;
	import away3d.arcane;
	import away3d.core.base.Geometry;
	import away3d.core.base.SubGeometry;
	import away3d.entities.Mesh;
	import away3d.loaders.misc.ResourceDependency;
	import away3d.materials.TextureMaterial;
	import away3d.textures.BitmapTexture;
	import away3d.textures.Texture2DBase;
	
	import com.mgsoft.mg3dengine.MG3DGlobals;
	
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
			TextureMaterial(_mesh.material).texture = new BitmapTexture(defaultBitmapData);
		} 
		
		
		/**
		 * @inheritDoc
		 */
		protected override function proceedParsing() : Boolean
		{
			if(!_startedParsing) {
				_byteData = getByteData();
				_startedParsing = true;
			}
			
			while (hasTime()) {
				if (!_parsedHeader) {
					_byteData.endian = Endian.LITTLE_ENDIAN;
					
					// TODO: Create a mesh only when encountered (if it makes sense
					// for this file format) and return it using finalizeAsset()
					_mesh = new Mesh;
					_mesh.material = new TextureMaterial( new BitmapTexture(defaultBitmapData) );
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
									finalizeAsset(_mesh);
									return true;
								}								
							}								
							
						}
					}
				}
			}
			
			// TODO: Can this be done a nicer fashion for this file format? Or does
			// it always just return a single mesh, in which case this should be fine
			
			
			return false;
		}
		
		private function buildMesh():void
		{
			
			for (var i:int = 0; i < _cant_layers; i++) 
			{
				
				var indices: Vector.<uint> = new Vector.<uint>();
				for (var j:int = 0; j < _cant_faces; j++) 
				{
					if (_atributos[j] == i)
					{
						indices.push(j*3);
						indices.push(j*3 + 1);
						indices.push(j*3 + 2);
					}
					
				}
				
				if(indices.length <= 0)
					continue;
				
				//guardo el id para poder identificar el nro_layer con el nro se subgeometry
				_id_subgeometry.push(i);
				
				var sub : SubGeometry = new SubGeometry();
				
				_geometry.addSubGeometry(sub);
				sub.updateVertexData(_vertices);
				sub.updateUVData(_uvs);
				sub.updateVertexNormalData(_normals);					
				sub.updateIndexData(indices);
				_mesh.subMeshes[_geometry.subGeometries.length - 1].material = new TextureMaterial(null, true, true);
				_mesh.subMeshes[_geometry.subGeometries.length - 1].material.bothSides = true;
				sub.nroLayer = i;
			}
			
			//le agrego un padre para que no lo dibuje en pantalla con la posicion 0,0,0
			_mesh.setParent(new Mesh());
			
			_createMesh = true;
		}
		
		private function parsedAtributos():void
		{
			_atributos = new Vector.<uint>();
			
			var cant_atrib:int = _cant_faces;
			
			for (var i:int = 0; i < cant_atrib; i++)
			{
				_atributos.push(_byteData.readInt());
			}
			
			_parsedAtributos = true;			
		}
		
		private function parseIndices():void
		{
			_indices = new Vector.<uint>();
			
			var cant_indices:int = _cant_faces * 3;
			
			for (var i:int = 0; i < cant_indices; i++)
			{
				_indices.push(_byteData.readInt());
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
			
			//bytes por vertice
			_sizeof_vertex = _byteData.readInt();
			
			//vertices
			_cant_vertices = _cant_faces*3;			
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
				
				var u:Number = _byteData.readFloat();
				var v:Number = _byteData.readFloat();
				//_uvs.push(new UV(u, v));
				_uvs.push(u);
				_uvs.push(v);
			}
			
			_parsedVertices = true;

		}
		
		private function parseLayers():void
		{
			var url : String;
			var name : String;
			_materialNames = new Vector.<String>();
			
			//cantidad de layers
			_cant_layers = _byteData.readInt();
			for (var i:int = 0; i < _cant_layers; i++)
			{
				//nombre de la textura
				
				name = _byteData.readUTFBytes(256);
				//name = name.substring(0, name.search('\0'));
				url = MG3DGlobals.TEXTURE_FOLDER + name;
				//url = "http://www.lepton.com.ar/download/armarius/texturas/05-nogal.jpg";
				//url = "http://www.lepton.com.ar/download/armarius/texturas/05-nogal.bmp";
				
				_materialNames[i] = name;
				
				if(name != "")
					addDependency(name, new URLRequest(url));
				
				//material
				//Material mat = new Material();
				//mat.Diffuse = FileUtils.ReadVector4(fs);
				//mat.Ambient = FileUtils.ReadVector4(fs);
				//mat.Specular = FileUtils.ReadVector4(fs);
				//mat.Emissive = FileUtils.ReadVector4(fs);
				//mat.Power = br.ReadSingle();
				
				//leo 17 floats del material del subset
				_byteData.readBytes(new ByteArray(), 0, 17*4);
				
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

