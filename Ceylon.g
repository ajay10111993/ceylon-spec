grammar Ceylon;

options {
    memoize=false;
}

@parser::header { package com.redhat.ceylon.compiler.typechecker.parser;
                  import com.redhat.ceylon.compiler.typechecker.tree.Node;
                  import static com.redhat.ceylon.compiler.typechecker.tree.CustomTree.*;
                  import static com.redhat.ceylon.compiler.typechecker.tree.CustomTree.Package; }
@lexer::header { package com.redhat.ceylon.compiler.typechecker.parser; }

@members {
    private java.util.List<ParseError> errors 
            = new java.util.ArrayList<ParseError>();
    @Override public void displayRecognitionError(String[] tn,
            RecognitionException re) {
        errors.add(new ParseError(this, re, tn));
    }
    public void displayRecognitionError(String[] tn, RecognitionException re, int code) {
        errors.add(new ParseError(this, re, tn, code));
    }
    public java.util.List<ParseError> getErrors() {
        return errors;
    }
    int expecting=-1;
}

@lexer::members {
    private java.util.List<LexError> errors 
            = new java.util.ArrayList<LexError>();
    @Override public void displayRecognitionError(String[] tn,
            RecognitionException re) {
        errors.add(new LexError(this, re, tn));
    }
    public java.util.List<LexError> getErrors() {
        return errors;
    }
}

compilationUnit returns [CompilationUnit compilationUnit]
    : { $compilationUnit = new CompilationUnit(null); }
      ( 
        ca1=compilerAnnotations
        SEMICOLON
        { $compilationUnit.getCompilerAnnotations().addAll($ca1.annotations); }
      )?
      (
        (compilerAnnotations annotations MODULE)=>
        moduleDescriptor 
        { $compilationUnit.setModuleDescriptor($moduleDescriptor.moduleDescriptor); }
      | 
        (compilerAnnotations annotations PACKAGE)=>
        packageDescriptor
        { $compilationUnit.setPackageDescriptor($packageDescriptor.packageDescriptor); }
      |
        importList 
        { $compilationUnit.setImportList($importList.importList); }
        ( 
          ca2=compilerAnnotations declaration
          { if ($declaration.declaration!=null)
                $compilationUnit.addDeclaration($declaration.declaration); 
            if ($declaration.declaration!=null)
                $declaration.declaration.getCompilerAnnotations().addAll($ca2.annotations); } 
        )*
      )
      EOF
    ;

moduleDescriptor returns [ModuleDescriptor moduleDescriptor]
    : compilerAnnotations annotations
      MODULE 
      { $moduleDescriptor = new ModuleDescriptor($MODULE); 
        $moduleDescriptor.setAnnotationList($annotations.annotationList);
        $moduleDescriptor.getCompilerAnnotations().addAll($compilerAnnotations.annotations); }
      packagePath
      { $moduleDescriptor.setImportPath($packagePath.importPath); }
      CHAR_LITERAL
      { $moduleDescriptor.setVersion(new QuotedLiteral($CHAR_LITERAL)); }
      importModuleList
      { $moduleDescriptor.setImportModuleList($importModuleList.importModuleList); }
    ;

importModuleList returns [ImportModuleList importModuleList]
    : LBRACE
      { $importModuleList = new ImportModuleList($LBRACE); }
      (
        compilerAnnotations annotations
        importModule
        { if ($importModule.importModule!=null)
              $importModuleList.addImportModule($importModule.importModule); 
          if ($importModule.importModule!=null)
              $importModule.importModule.setAnnotationList($annotations.annotationList);
          if ($importModule.importModule!=null)
              $importModule.importModule.getCompilerAnnotations().addAll($compilerAnnotations.annotations); }
      )*
      RBRACE
      { $importModuleList.setEndToken($RBRACE); }
    ;

packageDescriptor returns [PackageDescriptor packageDescriptor]
    : compilerAnnotations annotations
      PACKAGE 
      { $packageDescriptor = new PackageDescriptor($PACKAGE); 
        $packageDescriptor.setAnnotationList($annotations.annotationList); 
        $packageDescriptor.getCompilerAnnotations().addAll($compilerAnnotations.annotations); }
      packagePath
      { $packageDescriptor.setImportPath($packagePath.importPath); 
        expecting=SEMICOLON; }
      SEMICOLON
      { $packageDescriptor.setEndToken($SEMICOLON); 
        expecting=-1; }
    ;

importModule returns [ImportModule importModule]
    : IMPORT
      { $importModule = new ImportModule($IMPORT); }
      ( 
        q1=CHAR_LITERAL
        { $importModule.setQuotedLiteral(new QuotedLiteral($q1)); }
      |
        packagePath
        { $importModule.setImportPath($packagePath.importPath); }
      )
      q2=CHAR_LITERAL
      { $importModule.setVersion(new QuotedLiteral($q2)); 
        expecting=SEMICOLON; }
      SEMICOLON
      { $importModule.setEndToken($SEMICOLON); 
        expecting=-1; }
    ;

importList returns [ImportList importList]
    : { $importList = new ImportList(null); } 
      ( importDeclaration { $importList.addImport($importDeclaration.importDeclaration); } )*
    ;

importDeclaration returns [Import importDeclaration]
    : IMPORT 
      { $importDeclaration = new Import($IMPORT); } 
      (
        DYNAMIC
        { $importDeclaration = new ImportDynamic($IMPORT); 
          $importDeclaration.setImportPath(new ImportPath(null)); }
      |
        packagePath
        { $importDeclaration.setImportPath($packagePath.importPath); }
      | { displayRecognitionError(getTokenNames(), 
              new MismatchedTokenException(LIDENTIFIER, input)); }
      )
      importElementList
      { $importDeclaration.setImportMemberOrTypeList($importElementList.importMemberOrTypeList); }
    ;

importElementList returns [ImportMemberOrTypeList importMemberOrTypeList]
    @init { ImportMemberOrTypeList il=null; 
            boolean wildcarded = false; }
    :
    LBRACE
    { il = new ImportMemberOrTypeList($LBRACE);
      $importMemberOrTypeList = il; }
    ( 
      ie1=importElement 
      { if ($ie1.importMemberOrType!=null)
            il.addImportMemberOrType($ie1.importMemberOrType); } 
      ( 
        c1=COMMA 
        { il.setEndToken($c1); 
          if (wildcarded) 
              displayRecognitionError(getTokenNames(), 
                  new MismatchedTokenException(RBRACE, input)); }
        (
          ie2=importElement 
          { if ($ie2.importMemberOrType!=null)
                il.addImportMemberOrType($ie2.importMemberOrType);
            if ($ie2.importMemberOrType!=null)
                il.setEndToken(null); } 
        | iw=importWildcard
          { wildcarded = true;
            if ($iw.importWildcard!=null) 
                il.setImportWildcard($iw.importWildcard); 
            if ($iw.importWildcard!=null) 
                il.setEndToken(null); } 
        | { displayRecognitionError(getTokenNames(), 
                new MismatchedTokenException(ELLIPSIS, input)); }
        )
      )*
    | iw=importWildcard { il.setImportWildcard($iw.importWildcard); }
    )?
    RBRACE
    { il.setEndToken($RBRACE); }
    ;

importElement returns [ImportMemberOrType importMemberOrType]
    @init { Alias alias = null; }
    : compilerAnnotations
    ( in1=importName 
      { $importMemberOrType = new ImportMember(null);
        $importMemberOrType.setIdentifier($in1.identifier); }
      ( SPECIFY
        { alias = new Alias($SPECIFY);
          alias.setIdentifier($in1.identifier);
          $importMemberOrType.setAlias(alias); 
          $importMemberOrType.setIdentifier(null); }
        (
          in2=importName 
          { $importMemberOrType.setIdentifier($in2.identifier); }
        | { displayRecognitionError(getTokenNames(), 
                  new MismatchedTokenException($in1.identifier.getToken().getType(), input)); }
        )
      )?
      (
        iel2=importElementList
        { $importMemberOrType.setImportMemberOrTypeList($iel2.importMemberOrTypeList); }
      )?
    )
    { if ($importMemberOrType!=null)
        $importMemberOrType.getCompilerAnnotations().addAll($compilerAnnotations.annotations); }
    ;

importWildcard returns [ImportWildcard importWildcard]
    : ELLIPSIS
      { $importWildcard = new ImportWildcard($ELLIPSIS); }
    ;

importName returns [Identifier identifier]
    : memberName { $identifier=$memberName.identifier; }
    | typeName { $identifier=$typeName.identifier; }
    ;

packagePath returns [ImportPath importPath]
    @init { $importPath = new ImportPath(null); }
    : pn1=packageName 
      { if ($pn1.identifier!=null) 
            $importPath.addIdentifier($pn1.identifier); } 
      ( 
        m=MEMBER_OP 
        { $importPath.setEndToken($m); }
        (
          pn2=packageName 
          { $importPath.addIdentifier($pn2.identifier); 
            $importPath.setEndToken(null); }
        | { displayRecognitionError(getTokenNames(), 
                new MismatchedTokenException(LIDENTIFIER, input)); }
        )
      )*
    ;

packageName returns [Identifier identifier]
    : LIDENTIFIER
      { $identifier = new Identifier($LIDENTIFIER);
        $LIDENTIFIER.setType(PIDENTIFIER);}
    | { displayRecognitionError(getTokenNames(),
              new MismatchedTokenException(LIDENTIFIER, input), 5001); }
      UIDENTIFIER
      { $identifier = new Identifier($UIDENTIFIER);
        $UIDENTIFIER.setType(PIDENTIFIER);}
    ;

typeName returns [Identifier identifier]
    : UIDENTIFIER
      { $identifier = new Identifier($UIDENTIFIER); }
    ;

annotationName returns [Identifier identifier]
    : LIDENTIFIER
      { $identifier = new Identifier($LIDENTIFIER); 
        $LIDENTIFIER.setType(AIDENTIFIER); }
    ;

memberName returns [Identifier identifier]
    : LIDENTIFIER
      { $identifier = new Identifier($LIDENTIFIER); }
    ;
    
memberNameDeclaration returns [Identifier identifier]
    : memberName { $identifier = $memberName.identifier; }
    | { displayRecognitionError(getTokenNames(), 
              new MismatchedTokenException(LIDENTIFIER, input), 5001); }
      typeName { $identifier = $typeName.identifier; }
      
    ;

typeNameDeclaration returns [Identifier identifier]
    : typeName { $identifier = $typeName.identifier; }
    | { displayRecognitionError(getTokenNames(), 
              new MismatchedTokenException(UIDENTIFIER, input), 5002); }
      memberName { $identifier = $memberName.identifier; }
      
    ;

objectDeclaration returns [ObjectDefinition declaration]
    : OBJECT_DEFINITION
      { $declaration = new ObjectDefinition($OBJECT_DEFINITION); 
        $declaration.setType(new ValueModifier(null)); }
      memberNameDeclaration
      { $declaration.setIdentifier($memberNameDeclaration.identifier); }
      ( 
        extendedType
        { $declaration.setExtendedType($extendedType.extendedType); } 
      )?
      ( 
        satisfiedTypes
        { $declaration.setSatisfiedTypes($satisfiedTypes.satisfiedTypes); } 
      )?
      (
        classBody
        { $declaration.setClassBody($classBody.classBody); }
      | { displayRecognitionError(getTokenNames(), 
              new MismatchedTokenException(LBRACE, input)); }
        SEMICOLON
        { $declaration.setEndToken($SEMICOLON); }
      )
    ;

voidOrInferredMethodDeclaration returns [AnyMethod declaration]
    @init { MethodDefinition def=null;
            MethodDeclaration dec=null; }
    : (
        VOID_MODIFIER
        { VoidModifier vm = new VoidModifier($VOID_MODIFIER);
          def = new MethodDefinition($VOID_MODIFIER);
          dec = new MethodDeclaration($VOID_MODIFIER);
          def.setType(vm);
          dec.setType(vm);
          $declaration = dec; }
      | FUNCTION_MODIFIER
        { FunctionModifier fm = new FunctionModifier($FUNCTION_MODIFIER);
          def = new MethodDefinition($FUNCTION_MODIFIER);
          dec = new MethodDeclaration($FUNCTION_MODIFIER);
          def.setType(fm);
          dec.setType(fm);
          $declaration = dec; }
      )
      memberNameDeclaration
      { dec.setIdentifier($memberNameDeclaration.identifier); 
        def.setIdentifier($memberNameDeclaration.identifier); }
      (
        typeParameters
        { def.setTypeParameterList($typeParameters.typeParameterList); 
          dec.setTypeParameterList($typeParameters.typeParameterList); }        
      )?
      (
        parameters
        { def.addParameterList($parameters.parameterList); 
          dec.addParameterList($parameters.parameterList); }
      )*
      //metatypes? 
      (
        typeConstraints
        { def.setTypeConstraintList($typeConstraints.typeConstraintList); 
          dec.setTypeConstraintList($typeConstraints.typeConstraintList); }
      )?
      ( 
        { $declaration = def; }
        block 
        { def.setBlock($block.block); }
      | 
        (
          lazySpecifier
          { dec.setSpecifierExpression($lazySpecifier.specifierExpression); }
        )?
        { expecting=SEMICOLON; }
        SEMICOLON
        { expecting=-1; }
        { $declaration.setEndToken($SEMICOLON); }
      )
    ;

setterDeclaration returns [AttributeSetterDefinition declaration]
    : ASSIGN 
      { $declaration = new AttributeSetterDefinition($ASSIGN); 
        $declaration.setType( new VoidModifier(null) ); }
      memberNameDeclaration 
      { $declaration.setIdentifier($memberNameDeclaration.identifier); }
      ( 
        block
        { $declaration.setBlock($block.block); }
      | { displayRecognitionError(getTokenNames(), 
              new MismatchedTokenException(LBRACE, input)); }
        SEMICOLON
        { $declaration.setEndToken($SEMICOLON); }
      )
    ;

inferredAttributeDeclaration returns [AnyAttribute declaration]
    @init { AttributeGetterDefinition def=null;
            AttributeDeclaration dec=null; }
    : VALUE_MODIFIER 
      { ValueModifier fm = new ValueModifier($VALUE_MODIFIER);
        def = new AttributeGetterDefinition($VALUE_MODIFIER);
        dec = new AttributeDeclaration($VALUE_MODIFIER);
        def.setType(fm);
        dec.setType(fm);
        $declaration = dec; }
      memberNameDeclaration
      { dec.setIdentifier($memberNameDeclaration.identifier); 
        def.setIdentifier($memberNameDeclaration.identifier); }
      ( 
        (
          specifier
          { dec.setSpecifierOrInitializerExpression($specifier.specifierExpression); }
        | 
          lazySpecifier
          { dec.setSpecifierOrInitializerExpression($lazySpecifier.specifierExpression); }
        )?
        { expecting=SEMICOLON; }
        SEMICOLON
        { $declaration.setEndToken($SEMICOLON); 
          expecting=-1; }
      | 
        { $declaration = def; }
        block
        { def.setBlock($block.block); }
      )
    ;

typedMethodOrAttributeDeclaration returns [TypedDeclaration declaration]
    @init { AttributeGetterDefinition adef=new AttributeGetterDefinition(null);
            AttributeDeclaration adec=new AttributeDeclaration(null);
            MethodDefinition mdef=new MethodDefinition(null);
            MethodDeclaration mdec=new MethodDeclaration(null); 
            $declaration = adec; }
    : variadicType
      { adef.setType($variadicType.type);
        adec.setType($variadicType.type); 
        mdef.setType($variadicType.type);
        mdec.setType($variadicType.type); }
      memberNameDeclaration
      { adef.setIdentifier($memberNameDeclaration.identifier);
        adec.setIdentifier($memberNameDeclaration.identifier); 
        mdef.setIdentifier($memberNameDeclaration.identifier);
        mdec.setIdentifier($memberNameDeclaration.identifier); }
      ( 
        { $declaration = mdec; }
        (
          typeParameters
          { mdef.setTypeParameterList($typeParameters.typeParameterList);
            mdec.setTypeParameterList($typeParameters.typeParameterList); }
        )?
        (
          parameters
          { mdef.addParameterList($parameters.parameterList);
            mdec.addParameterList($parameters.parameterList); }
        )+
        //metatypes? 
        ( 
          typeConstraints
          { mdef.setTypeConstraintList($typeConstraints.typeConstraintList);
            mdec.setTypeConstraintList($typeConstraints.typeConstraintList); }
        )?
        ( 
          { $declaration = mdef; }
          b1=block
         { mdef.setBlock($b1.block); }
        | 
          (
            ms=lazySpecifier
           { mdec.setSpecifierExpression($ms.specifierExpression); }
          )?
          { expecting=SEMICOLON; }
          s1=SEMICOLON
          { $declaration.setEndToken($s1);
            expecting=-1; }
        )
      | 
        (
          as=specifier 
          { adec.setSpecifierOrInitializerExpression($as.specifierExpression); }
        | 
          ac=lazySpecifier 
          { adec.setSpecifierOrInitializerExpression($ac.specifierExpression); }
        )?
        { expecting=SEMICOLON; }
        s2=SEMICOLON
        { $declaration.setEndToken($s2); 
        expecting=-1; }
      | 
        { $declaration = adef; }
        b2=block
        { adef.setBlock($b2.block); }
      )
    ;

interfaceDeclaration returns [AnyInterface declaration]
    @init { InterfaceDefinition def=null; 
            InterfaceDeclaration dec=null; }
    : INTERFACE_DEFINITION
      { def = new InterfaceDefinition($INTERFACE_DEFINITION); 
        dec = new InterfaceDeclaration($INTERFACE_DEFINITION);
        $declaration = dec; }
      typeNameDeclaration 
      { dec.setIdentifier($typeNameDeclaration.identifier); 
        def.setIdentifier($typeNameDeclaration.identifier); }
      (
        typeParameters 
        { def.setTypeParameterList($typeParameters.typeParameterList); 
          dec.setTypeParameterList($typeParameters.typeParameterList); }
      )?
      (
        caseTypes
        { def.setCaseTypes($caseTypes.caseTypes); 
          dec.setCaseTypes($caseTypes.caseTypes); }
      )?
      /*metatypes?*/ 
      /*(
        adaptedTypes
        { def.setAdaptedTypes($adaptedTypes.adaptedTypes); }
      )?*/
      (
        satisfiedTypes
        { def.setSatisfiedTypes($satisfiedTypes.satisfiedTypes); 
          dec.setSatisfiedTypes($satisfiedTypes.satisfiedTypes); }
      )?
      (
        typeConstraints
        { def.setTypeConstraintList($typeConstraints.typeConstraintList); 
          dec.setTypeConstraintList($typeConstraints.typeConstraintList); }
      )?
      (
        { $declaration = def; }
        interfaceBody
        { def.setInterfaceBody($interfaceBody.interfaceBody); }
      | 
        (
          typeSpecifier
          { dec.setTypeSpecifier($typeSpecifier.typeSpecifier); }
        )? 
        { expecting=SEMICOLON; }
        SEMICOLON
        { $declaration.setEndToken($SEMICOLON); 
          expecting=-1; }
      )
    ;

classDeclaration returns [AnyClass declaration]
    @init { ClassDefinition def=null; 
            ClassDeclaration dec=null; }
    : CLASS_DEFINITION 
      { def = new ClassDefinition($CLASS_DEFINITION); 
        dec = new ClassDeclaration($CLASS_DEFINITION);
        $declaration = dec; }
      typeNameDeclaration
      { dec.setIdentifier($typeNameDeclaration.identifier); 
        def.setIdentifier($typeNameDeclaration.identifier); }
      (
        typeParameters
        { def.setTypeParameterList($typeParameters.typeParameterList); 
          dec.setTypeParameterList($typeParameters.typeParameterList); }
      )?
      (
        parameters
        { def.setParameterList($parameters.parameterList); 
          dec.setParameterList($parameters.parameterList); }
      )?
      (
        caseTypes
        { def.setCaseTypes($caseTypes.caseTypes); 
          dec.setCaseTypes($caseTypes.caseTypes); }
      )?
      /*metatypes?*/ 
      (
        extendedType
        { def.setExtendedType($extendedType.extendedType); 
          dec.setExtendedType($extendedType.extendedType); }
      )? 
      (
        satisfiedTypes
        { def.setSatisfiedTypes($satisfiedTypes.satisfiedTypes); 
          dec.setSatisfiedTypes($satisfiedTypes.satisfiedTypes); }
      )?
      (
        typeConstraints
        { def.setTypeConstraintList($typeConstraints.typeConstraintList); 
          dec.setTypeConstraintList($typeConstraints.typeConstraintList); }
      )?
      (
        { $declaration = def; }
        classBody
        { def.setClassBody($classBody.classBody); }
      | 
        (
          classSpecifier
          { dec.setClassSpecifier($classSpecifier.classSpecifier); }
        )?
        { expecting=SEMICOLON; }
        SEMICOLON
        { $declaration.setEndToken($SEMICOLON); 
          expecting=-1; }
      )
    ;

aliasDeclaration returns [TypeAliasDeclaration declaration]
    : ALIAS
      { $declaration = new TypeAliasDeclaration($ALIAS);}
      typeNameDeclaration 
      { $declaration.setIdentifier($typeNameDeclaration.identifier); }
      (
        typeParameters 
        { $declaration.setTypeParameterList($typeParameters.typeParameterList); }
      )?
      (
        typeConstraints
        { $declaration.setTypeConstraintList($typeConstraints.typeConstraintList); }
      )?
      (
        typeSpecifier
        { $declaration.setTypeSpecifier($typeSpecifier.typeSpecifier); }
      )?
      { expecting=SEMICOLON; }
      SEMICOLON
      { $declaration.setEndToken($SEMICOLON); 
        expecting=-1; }
    ;

assertion returns [Assertion assertion]
    : annotations
      ASSERT
      { $assertion = new Assertion($ASSERT); 
        $assertion.setAnnotationList($annotations.annotationList); }
      conditions
      { $assertion.setConditionList($conditions.conditionList); }
      { expecting=SEMICOLON; }
      SEMICOLON
      { $assertion.setEndToken($SEMICOLON); 
        expecting=-1; }
    ;

block returns [Block block]
    : LBRACE 
      { $block = new Block($LBRACE); }
      (
        declarationOrStatement
        { if ($declarationOrStatement.statement!=null)
              $block.addStatement($declarationOrStatement.statement); }
      )*
      RBRACE
      { $block.setEndToken($RBRACE); }
    ;

//Note: interface bodies can't really contain 
//      statements, but error recovery works
//      much better if we validate that later
//      on, instead of doing it in the parser.
interfaceBody returns [InterfaceBody interfaceBody]
    : LBRACE 
      { $interfaceBody = new InterfaceBody($LBRACE); }
      (
        declarationOrStatement
        { if ($declarationOrStatement.statement!=null)
              $interfaceBody.addStatement($declarationOrStatement.statement); }
      )*
      RBRACE
      { $interfaceBody.setEndToken($RBRACE); }
    ;

classBody returns [ClassBody classBody]
    : LBRACE
      { $classBody = new ClassBody($LBRACE); }
      (
        declarationOrStatement
        { if ($declarationOrStatement.statement!=null)
              $classBody.addStatement($declarationOrStatement.statement); }
      )*
      RBRACE
      { $classBody.setEndToken($RBRACE); }
    ;

extendedType returns [ExtendedType extendedType]
    : EXTENDS { $extendedType = new ExtendedType($EXTENDS); }
      ci=classInstantiation
      { $extendedType.setType($ci.type);
        $extendedType.setInvocationExpression($ci.invocationExpression); }
    ;

classSpecifier returns [ClassSpecifier classSpecifier]
    : COMPUTE { $classSpecifier = new ClassSpecifier($COMPUTE); }
      ci=classInstantiation
      { $classSpecifier.setType($ci.type);
        $classSpecifier.setInvocationExpression($ci.invocationExpression); }
    ;

classInstantiation returns [SimpleType type, InvocationExpression invocationExpression]
    : (
        qualifiedType
        { $type=$qualifiedType.type; }
      | SUPER MEMBER_OP 
        typeReference 
        { QualifiedType qt=new QualifiedType(null);
          SuperType st = new SuperType($SUPER);
          qt.setOuterType(st);
          qt.setIdentifier($typeReference.identifier);
          if ($typeReference.typeArgumentList!=null)
              qt.setTypeArgumentList($typeReference.typeArgumentList);
          $type=qt; }
      )
      (
        positionalArguments
        { InvocationExpression ie = new InvocationExpression(null);
          ExtendedTypeExpression ete = new ExtendedTypeExpression(null);
          ie.setPrimary(ete);
          ete.setExtendedType($type);
          ie.setPositionalArgumentList($positionalArguments.positionalArgumentList);
          $invocationExpression=ie; }
      | /*{ displayRecognitionError(getTokenNames(),
            new MismatchedTokenException(LPAREN, input)); }*/
      )
    ;

satisfiedTypes returns [SatisfiedTypes satisfiedTypes]
    : SATISFIES 
      { $satisfiedTypes = new SatisfiedTypes($SATISFIES); }
      ( 
        t1=abbreviatedType 
        { $satisfiedTypes.addType($t1.type); }
      )
      (
        i=INTERSECTION_OP
        { $satisfiedTypes.setEndToken($i); }
        (
          t2=abbreviatedType
          { $satisfiedTypes.addType($t2.type); 
            $satisfiedTypes.setEndToken(null); }
        )
      )*
    ;

abstractedType returns [AbstractedType abstractedType]
    : ABSTRACTED_TYPE
      { $abstractedType = new AbstractedType($ABSTRACTED_TYPE); }
      qualifiedType
      { $abstractedType.setType($qualifiedType.type); }
    ;

/*adaptedTypes returns [AdaptedTypes adaptedTypes]
    : ADAPTED_TYPES 
      { $adaptedTypes = new AdaptedTypes($ADAPTED_TYPES); }
      t1=qualifiedType 
      { $adaptedTypes.addType($t1.type); }
      (
        i=INTERSECTION_OP 
        { $adaptedTypes.setEndToken($i); }
        (
          t2=qualifiedType
          { $adaptedTypes.addType($t2.type); 
            $adaptedTypes.setEndToken(null); }
        | { displayRecognitionError(getTokenNames(),
              new MismatchedTokenException(UIDENTIFIER, input)); }
        )
      )*
    ;*/

caseTypes returns [CaseTypes caseTypes]
    : CASE_TYPES
      { $caseTypes = new CaseTypes($CASE_TYPES); }
      ct1=caseType 
      { if ($ct1.type!=null) $caseTypes.addType($ct1.type); 
        if ($ct1.instance!=null) $caseTypes.addBaseMemberExpression($ct1.instance); }
      (
        u=UNION_OP 
        { $caseTypes.setEndToken($u); }
        (
          ct2=caseType
          { if ($ct2.type!=null) $caseTypes.addType($ct2.type); 
            if ($ct2.instance!=null) $caseTypes.addBaseMemberExpression($ct2.instance); 
            $caseTypes.setEndToken(null); }
        )
      )*
    ;

caseType returns [StaticType type, BaseMemberExpression instance]
    : t=abbreviatedType 
      { $type=$t.type;}
    | memberName
      { $instance = new BaseMemberExpression(null);
        $instance.setIdentifier($memberName.identifier);
        $instance.setTypeArguments( new InferredTypeArguments(null) ); }
    /*| classDeclaration
    | objectDeclaration*/
    ;

//Support for metatypes
//Note that we don't need this for now
/*metatypes
    : IS_OP type ('&' type)* 
    -> ^(METATYPES[$IS_OP] type*)
    ;*/

parameters returns [ParameterList parameterList]
    : LPAREN
      { $parameterList=new ParameterList($LPAREN); }
      (
        ap1=parameterDeclaration 
        { if ($ap1.parameter!=null)
              $parameterList.addParameter($ap1.parameter); }
        (
          c=COMMA
          { $parameterList.setEndToken($c); }
          (
            ap2=parameterDeclaration
            { $parameterList.addParameter($ap2.parameter); 
              $parameterList.setEndToken(null); }
          |
            { displayRecognitionError(getTokenNames(),
                new MismatchedTokenException(UIDENTIFIER, input)); }
          )
        )*
      )?
      RPAREN
      { $parameterList.setEndToken($RPAREN); }
    ;

// FIXME: This accepts more than the language spec: named arguments
// and varargs arguments can appear in any order.  We'll have to
// enforce the rule that the ... appears at the end of the parapmeter
// list in a later pass of the compiler.
parameter returns [Parameter parameter]
    @init { ValueParameterDeclaration vp = new ValueParameterDeclaration(null); 
            FunctionalParameterDeclaration fp = new FunctionalParameterDeclaration(null); 
            $parameter = vp; }
    : ( 
        variadicType
        { vp.setType($variadicType.type);
          fp.setType($variadicType.type); }
      | VOID_MODIFIER
        { fp.setType(new VoidModifier($VOID_MODIFIER));
          $parameter=fp; }
      | FUNCTION_MODIFIER
        { fp.setType(new FunctionModifier($FUNCTION_MODIFIER));
          $parameter=fp; }
      | VALUE_MODIFIER
        { vp.setType(new ValueModifier($VALUE_MODIFIER)); }
      )
      memberName
      { vp.setIdentifier($memberName.identifier);
        fp.setIdentifier($memberName.identifier); }
      (
        (
          specifier
          { DefaultArgument da = new DefaultArgument(null);
            $parameter.setDefaultArgument(da);
            da.setSpecifierExpression($specifier.specifierExpression); }
        )?
      |
        (
          parameters
          { fp.addParameterList($parameters.parameterList);
            $parameter=fp; }
        )+
        (
          lazySpecifier
          { DefaultArgument da = new DefaultArgument(null);
            $parameter.setDefaultArgument(da);
            da.setSpecifierExpression($lazySpecifier.specifierExpression); }
        )?
      )
    ;

parameterRef returns [InitializerParameter parameter]
    : memberName
      { $parameter = new InitializerParameter(null);
        $parameter.setType(new ValueModifier(null));
        $parameter.setIdentifier($memberName.identifier); }
      (
        specifier
        { DefaultArgument da = new DefaultArgument(null);
          da.setSpecifierExpression($specifier.specifierExpression);
          $parameter.setDefaultArgument(da); }
      )?
    ;

parameterDeclaration returns [Parameter parameter]
    : compilerAnnotations
      (
        r=parameterRef
        { $parameter=$r.parameter; }
      | 
        annotations 
        p=parameter
        { $parameter=$p.parameter;
          $parameter.setAnnotationList($annotations.annotationList); }
      )
      { if ($parameter!=null)
        $parameter.getCompilerAnnotations().addAll($compilerAnnotations.annotations); }
    ;

typeParameters returns [TypeParameterList typeParameterList]
    : SMALLER_OP
      { $typeParameterList = new TypeParameterList($SMALLER_OP); }
      tp1=typeParameter
      { if ($tp1.typeParameter instanceof TypeParameterDeclaration)
            $typeParameterList.addTypeParameterDeclaration($tp1.typeParameter); }
      (
        c=COMMA
        { $typeParameterList.setEndToken($c); }
        (
          tp2=typeParameter
          { if ($tp2.typeParameter instanceof TypeParameterDeclaration)
                $typeParameterList.addTypeParameterDeclaration($tp2.typeParameter);
            $typeParameterList.setEndToken(null); }
        | { displayRecognitionError(getTokenNames(), 
                new MismatchedTokenException(UIDENTIFIER, input)); }
        )
      )*
      LARGER_OP
      { $typeParameterList.setEndToken($LARGER_OP); }
    ;

typeParameter returns [TypeParameterDeclaration typeParameter]
    : { $typeParameter = new TypeParameterDeclaration(null); }
      compilerAnnotations
      ( 
        variance 
        { $typeParameter.setTypeVariance($variance.typeVariance); } 
      )? 
      typeNameDeclaration
      { $typeParameter.setIdentifier($typeNameDeclaration.identifier); }
      (
        typeDefault
        { $typeParameter.setTypeSpecifier($typeDefault.typeSpecifier); }
      )?
      { $typeParameter.getCompilerAnnotations().addAll($compilerAnnotations.annotations); }
    ;

variance returns [TypeVariance typeVariance]
    : IN_OP
      { $typeVariance = new TypeVariance($IN_OP); }
    | OUT
      { $typeVariance = new TypeVariance($OUT); }
    ;
    
typeConstraint returns [TypeConstraint typeConstraint]
    : compilerAnnotations
      TYPE_CONSTRAINT
      { $typeConstraint = new TypeConstraint($TYPE_CONSTRAINT); 
        $typeConstraint.getCompilerAnnotations().addAll($compilerAnnotations.annotations); }
      typeNameDeclaration 
      { $typeConstraint.setIdentifier($typeNameDeclaration.identifier); }
      //(typeParameters)?
      (
        parameters
        { $typeConstraint.setParameterList($parameters.parameterList); }
      )?
      (
        caseTypes
        { $typeConstraint.setCaseTypes($caseTypes.caseTypes); }
      )?
      //metatypes? 
      (
        satisfiedTypes
        { $typeConstraint.setSatisfiedTypes($satisfiedTypes.satisfiedTypes); }
      )?
      ( 
        abstractedType
        { $typeConstraint.setAbstractedType($abstractedType.abstractedType); }
      )?
    ;

typeConstraints returns [TypeConstraintList typeConstraintList]
    : { $typeConstraintList=new TypeConstraintList(null); }
      (
        typeConstraint
        { $typeConstraintList.addTypeConstraint($typeConstraint.typeConstraint); }
      )+
    ;

annotationListStart
    : (stringLiteral|annotation) 
      (LIDENTIFIER|UIDENTIFIER|FUNCTION_MODIFIER|VOID_MODIFIER)
    ;

declarationOrStatement returns [Statement statement]
    options {memoize=true;}
    : compilerAnnotations
      ( 
        (annotatedDeclarationStart) => d=declaration
        { $statement=$d.declaration; }
      | (annotatedAssertionStart) => assertion
        { $statement = $assertion.assertion; }
      | (annotationListStart) => d1=declaration
        { $statement=$d1.declaration; }
      | s=statement
        { $statement=$s.statement; }
      )
      { if ($statement!=null)
            $statement.getCompilerAnnotations().addAll($compilerAnnotations.annotations); }
    ;

declaration returns [Declaration declaration]
    @init { $declaration = new MissingDeclaration(null); }
    : annotations
      { $declaration.setAnnotationList($annotations.annotationList); }
    ( 
      objectDeclaration
      { $declaration=$objectDeclaration.declaration; }
    | setterDeclaration
      { $declaration=$setterDeclaration.declaration; }
    | voidOrInferredMethodDeclaration
      { $declaration=$voidOrInferredMethodDeclaration.declaration; }
    | inferredAttributeDeclaration
      { $declaration=$inferredAttributeDeclaration.declaration; }
    | typedMethodOrAttributeDeclaration
      { $declaration=$typedMethodOrAttributeDeclaration.declaration; }
    | classDeclaration
      { $declaration=$classDeclaration.declaration; }
    | interfaceDeclaration
      { $declaration=$interfaceDeclaration.declaration; }
    | aliasDeclaration
      { $declaration=$aliasDeclaration.declaration; }
    /*| { displayRecognitionError(getTokenNames(), 
              new MismatchedTokenException(CLASS_DEFINITION, input)); }
      SEMICOLON
      { $declaration=new BrokenDeclaration($SEMICOLON); }*/
    )
    { $declaration.setAnnotationList($annotations.annotationList);  }
    ;

//special rule for syntactic predicate
//to distinguish between an annotation
//and an expression statement
/*annotatedDeclarationStart
    : declarationStart
    | LIDENTIFIER
      ( 
          declarationStart
        | LIDENTIFIER
        | nonstringLiteral | stringLiteral
        | arguments annotatedDeclarationStart //we need to recurse because it could be an inline callable argument
      )
    ;*/

annotatedDeclarationStart
    : stringLiteral? annotation* declarationStart
    ;

annotatedAssertionStart
    : stringLiteral? annotation* ASSERT
    ;

//special rule for syntactic predicates
//that distinguish declarations from
//expressions
declarationStart
    : VALUE_MODIFIER
    | FUNCTION_MODIFIER (LIDENTIFIER|UIDENTIFIER) //to disambiguate anon functions
    | VOID_MODIFIER (LIDENTIFIER|UIDENTIFIER) //to disambiguate anon functions
    | ASSIGN
    | INTERFACE_DEFINITION
    | CLASS_DEFINITION
    | OBJECT_DEFINITION
    | ALIAS 
    | variadicType LIDENTIFIER
    ;

statement returns [Statement statement]
    : directiveStatement
      { $statement = $directiveStatement.directive; }
    | controlStatement
      { $statement = $controlStatement.controlStatement; }
    | expressionOrSpecificationStatement
      { $statement = $expressionOrSpecificationStatement.statement; }
    ;

expressionOrSpecificationStatement returns [Statement statement]
    @init { SpecifierStatement ss=new SpecifierStatement(null); 
            ExpressionStatement es=new ExpressionStatement(null); }
    : expression
      { $statement = es;
        if ($expression.expression!=null)
            es.setExpression($expression.expression);
        if ($expression.expression.getTerm() instanceof AssignOp) {
            AssignOp a = (AssignOp) $expression.expression.getTerm();
            if (a.getLeftTerm() instanceof BaseMemberExpression ||
                a.getLeftTerm() instanceof ParameterizedExpression) {
                SpecifierExpression se = new SpecifierExpression(null);
                Expression e = new Expression(null);
                se.setExpression(e);
                e.setTerm(a.getRightTerm());
                ss.setSpecifierExpression(se);
                ss.setBaseMemberExpression(a.getLeftTerm());
                $statement = ss;
            }
        }
      }
      (
        /*specifier
        { ss.setSpecifierExpression($specifier.specifierExpression);
          ss.setBaseMemberExpression($expression.expression.getTerm());
          $statement = ss; }
      | */
        lazySpecifier
        { ss.setSpecifierExpression($lazySpecifier.specifierExpression);
          ss.setBaseMemberExpression($expression.expression.getTerm()); 
          $statement = ss; }
      )?
      { expecting=SEMICOLON; }
      (
        SEMICOLON
        { $statement.setEndToken($SEMICOLON); }
      | { displayRecognitionError(getTokenNames(), 
              new MismatchedTokenException(SEMICOLON, input)); }
        COMMA
        { $statement.setEndToken($COMMA); }
      )
      { expecting=-1; }
    ;

directiveStatement returns [Directive directive]
    : d=directive 
      { $directive=$d.directive; } 
      { expecting=SEMICOLON; }
      SEMICOLON
      { $directive.setEndToken($SEMICOLON); }
      { expecting=-1; }
    ;

directive returns [Directive directive]
    : returnDirective
      { $directive = $returnDirective.directive; }
    | throwDirective
      { $directive = $throwDirective.directive; }
    | breakDirective
      { $directive = $breakDirective.directive; }
    | continueDirective
      { $directive = $continueDirective.directive; }
    ;

returnDirective returns [Return directive]
    : RETURN 
      { $directive = new Return($RETURN); }
      (
        functionOrExpression
        { $directive.setExpression($functionOrExpression.expression); }
      )?
    ;

throwDirective returns [Throw directive]
    : THROW
      { $directive = new Throw($THROW); }
      ( 
        expression
        { $directive.setExpression($expression.expression); }
      )?
    ;

breakDirective returns [Break directive]
    : BREAK
      { $directive = new Break($BREAK); }
    ;

continueDirective returns [Continue directive]
    : CONTINUE
      { $directive = new Continue($CONTINUE); }
    ;

typeSpecifier returns [TypeSpecifier typeSpecifier]
    : COMPUTE 
      { $typeSpecifier = new TypeSpecifier($COMPUTE); }
      type
      { $typeSpecifier.setType($type.type); }
    ;

typeDefault returns [TypeSpecifier typeSpecifier]
    : SPECIFY 
      { $typeSpecifier = new TypeSpecifier($SPECIFY); }
      type
      { $typeSpecifier.setType($type.type); }
    ;

specifier returns [SpecifierExpression specifierExpression]
    : SPECIFY
      { $specifierExpression = new SpecifierExpression($SPECIFY); }
      functionOrExpression
      { $specifierExpression.setExpression($functionOrExpression.expression); }
    ;

lazySpecifier returns [SpecifierExpression specifierExpression]
    : COMPUTE
      { $specifierExpression = new LazySpecifierExpression($COMPUTE); }
      functionOrExpression
      { $specifierExpression.setExpression($functionOrExpression.expression); }
    ;

expression returns [Expression expression]
    : { $expression = new Expression(null); }
      assignmentExpression
      { $expression.setTerm($assignmentExpression.term); }
    ;

base returns [Primary primary]
    : nonstringLiteral
      { $primary=$nonstringLiteral.literal; }
    | stringExpression
      { $primary=$stringExpression.atom; }
    | enumeration
      { $primary=$enumeration.sequenceEnumeration; }
    | tuple
      { $primary=$tuple.tuple; }
    | selfReference
      { $primary=$selfReference.atom; }
    | parExpression
      { $primary=$parExpression.expression; }
    | baseReference
      { BaseMemberOrTypeExpression be;
        if ($baseReference.isMember)
            be = new BaseMemberExpression(null);
        else
            be = new BaseTypeExpression(null);
        if ($baseReference.qualifier!=null)
            be.setSupertypeQualifier($baseReference.qualifier);
        be.setIdentifier($baseReference.identifier);
        be.setTypeArguments( new InferredTypeArguments(null) );
        if ($baseReference.typeArgumentList!=null)
            be.setTypeArguments($baseReference.typeArgumentList);
        $primary=be; }
    ;

baseReference returns [Identifier identifier, SupertypeQualifier qualifier,
                       TypeArgumentList typeArgumentList, boolean isMember]
    : 
    (
      supertypeQualifier
      { $qualifier = $supertypeQualifier.qualifier; 
        $identifier = new Identifier($supertypeQualifier.qualifier.getToken());
        $identifier.setText("");
        $isMember=true; }
    )?
    (
      memberReference
      { $identifier = $memberReference.identifier;
        $typeArgumentList = $memberReference.typeArgumentList;
        $isMember = true; }
    | typeReference
      { $identifier = $typeReference.identifier;
        $typeArgumentList = $typeReference.typeArgumentList;
        $isMember = false; }
    )
    ;

supertypeQualifier returns [SupertypeQualifier qualifier]
    : typeName SUPER_OP
      { $qualifier = new SupertypeQualifier($SUPER_OP);
        $qualifier.setIdentifier($typeName.identifier); }
    ;

primary returns [Primary primary]
    : base
      { $primary=$base.primary; }
    (   
      //TODO: re-enable:
        /*inlineFunctionalArgument
      |*/ qualifiedReference
      { QualifiedMemberOrTypeExpression qe;
        if ($qualifiedReference.isMember)
            qe = new QualifiedMemberExpression(null);
        else
            qe = new QualifiedTypeExpression(null);
        qe.setPrimary($primary);
        qe.setMemberOperator($qualifiedReference.operator);
        qe.setIdentifier($qualifiedReference.identifier);
        qe.setTypeArguments( new InferredTypeArguments(null) );
        if ($qualifiedReference.typeArgumentList!=null)
            qe.setTypeArguments($qualifiedReference.typeArgumentList);
        $primary=qe; }
      | indexOrIndexRange 
        { $indexOrIndexRange.indexExpression.setPrimary($primary);
          $primary = $indexOrIndexRange.indexExpression; }
      | (specifierParametersStart)=> parameters
        { ParameterizedExpression pe;
          if ($primary instanceof ParameterizedExpression) {
              pe = (ParameterizedExpression) $primary;
          } else {
              pe = new ParameterizedExpression(null);
              pe.setPrimary($primary);
          }
          pe.addParameterList($parameters.parameterList);
          $primary = pe; }
      | arguments
        { InvocationExpression ie = new InvocationExpression(null);
          ie.setPrimary($primary);
          if ($arguments.argumentList instanceof PositionalArgumentList)
              ie.setPositionalArgumentList((PositionalArgumentList)$arguments.argumentList);
          if ($arguments.argumentList instanceof NamedArgumentList)
              ie.setNamedArgumentList((NamedArgumentList)$arguments.argumentList);
          $primary=ie; }
    )*
    ;

specifierParametersStart
    : LPAREN (compilerAnnotations annotatedDeclarationStart | RPAREN (SPECIFY|COMPUTE|specifierParametersStart))
    ;

qualifiedReference returns [Identifier identifier, MemberOperator operator, 
                            TypeArgumentList typeArgumentList, boolean isMember]
    : memberSelectionOperator 
      { $operator = $memberSelectionOperator.operator;
        $identifier = new Identifier($operator.getToken());
        $identifier.setText("");
        $isMember=true; }
      ( 
        memberReference
        { $identifier = $memberReference.identifier;
          $typeArgumentList = $memberReference.typeArgumentList; }
      | typeReference
        { $identifier = $typeReference.identifier;
          $typeArgumentList = $typeReference.typeArgumentList;  
          $isMember=false; }
      | (~(LIDENTIFIER|UIDENTIFIER))=>
        { displayRecognitionError(getTokenNames(), 
              new MismatchedTokenException(LIDENTIFIER, input)); }
      )
    ;

memberSelectionOperator returns [MemberOperator operator]
    : MEMBER_OP
      { $operator=new MemberOp($MEMBER_OP); }
    | SAFE_MEMBER_OP
      { $operator=new SafeMemberOp($SAFE_MEMBER_OP); }
    | SPREAD_OP
      { $operator=new SpreadOp($SPREAD_OP); }
    ;

enumeration returns [SequenceEnumeration sequenceEnumeration]
    : LBRACE 
      { $sequenceEnumeration = new SequenceEnumeration($LBRACE); } 
      (
        sequencedArgument
        { $sequenceEnumeration.setSequencedArgument($sequencedArgument.sequencedArgument); }
      )?
      RBRACE
      { $sequenceEnumeration.setEndToken($RBRACE); }
    ;

tuple returns [Tuple tuple]
    : LBRACKET 
      { $tuple = new Tuple($LBRACKET); }
      (
        sequencedArgument
        { $tuple.setSequencedArgument($sequencedArgument.sequencedArgument); }
      )?
      RBRACKET
      { $tuple.setEndToken($RBRACKET); }
    ;
    
expressions returns [ExpressionList expressionList]
    : { $expressionList = new ExpressionList(null); }
      e1=expression 
      { $expressionList.addExpression($e1.expression); }
      ( c=COMMA 
        { $expressionList.setEndToken($c); }
        (
          e2=expression 
          { $expressionList.addExpression($e2.expression);
            $expressionList.setEndToken(null); }
        | { displayRecognitionError(getTokenNames(), 
              new MismatchedTokenException(LIDENTIFIER, input)); } //TODO: sometimes it should be RPAREN!
        )
      )*
    ;

memberReference returns [Identifier identifier, 
        TypeArgumentList typeArgumentList]
    : memberName
      { $identifier = $memberName.identifier; }
      (
        (typeArgumentsStart)
        => typeArguments
        { $typeArgumentList = $typeArguments.typeArgumentList; }
      )?
    ;

typeReference returns [Identifier identifier, 
        TypeArgumentList typeArgumentList]
    : typeName 
      { $identifier = $typeName.identifier; }
      (
        (typeArgumentsStart)
        => typeArguments
        { $typeArgumentList = $typeArguments.typeArgumentList; }
      )?
    ;

//special rule for syntactic predicate to 
//determine if we have a < operator, or a
//type argument list
typeArgumentsStart
    : SMALLER_OP
    (
      type
      (LARGER_OP|SMALLER_OP|COMMA)
    |
      SMALLER_OP
    | 
      LARGER_OP //for IDE only!
    )
    ;

indexOrIndexRange returns [IndexExpression indexExpression]
    //TODO: move indexOperator to ElementOrRange and
    //      make this rule return ElementOrRange instead
    //      of IndexExpression, instantiating IndexExpression
    //      from the calling primary rule
    : LBRACKET
      { $indexExpression = new IndexExpression($LBRACKET); }
      (
        e1=ELLIPSIS
        { $indexExpression.setEndToken($e1); }
      i=index
      { ElementRange er0 = new ElementRange(null);
        $indexExpression.setElementOrRange(er0);
        er0.setUpperBound($i.expression); }
      |
      l=index
      { Element e = new Element(null);
        $indexExpression.setElementOrRange(e);
        e.setExpression($l.expression); }
      (
        e2=ELLIPSIS
        { $indexExpression.setEndToken($e2); }
      { ElementRange er1 = new ElementRange(null);
        $indexExpression.setElementOrRange(er1);
        er1.setLowerBound($l.expression); }
      | RANGE_OP 
        { $indexExpression.setEndToken($RANGE_OP); }
        u=index 
      { ElementRange er2 = new ElementRange(null);
        $indexExpression.setElementOrRange(er2);
        er2.setLowerBound($l.expression); 
        er2.setUpperBound($u.expression); }
      | SEGMENT_OP
        { $indexExpression.setEndToken($SEGMENT_OP); }
        s=index 
      { ElementRange er3 = new ElementRange(null);
        $indexExpression.setElementOrRange(er3);
        er3.setLowerBound($l.expression); 
        er3.setLength($s.expression); }
      )?
      )
      RBRACKET
      { $indexExpression.setEndToken($RBRACKET); }
    ;

index returns [Expression expression]
    : additiveExpression 
      { $expression = new Expression(null);
        $expression.setTerm($additiveExpression.term); }
    ;

arguments returns [ArgumentList argumentList]
    : positionalArguments 
      { $argumentList = $positionalArguments.positionalArgumentList; }
    | namedArguments
      { $argumentList = $namedArguments.namedArgumentList; }
    ;

namedArguments returns [NamedArgumentList namedArgumentList]
    : LBRACE 
      { $namedArgumentList = new NamedArgumentList($LBRACE); }
      ( //TODO: get rid of the predicate and use the approach
        //      in expressionOrSpecificationStatement
        (namedArgumentStart) 
        => namedArgument
        { if ($namedArgument.namedArgument!=null) 
              $namedArgumentList.addNamedArgument($namedArgument.namedArgument); }
      | (anonymousArgument)
        => anonymousArgument
        { if ($anonymousArgument.namedArgument!=null) 
              $namedArgumentList.addNamedArgument($anonymousArgument.namedArgument); }
      )*
      ( 
        sequencedArgument
        { $namedArgumentList.setSequencedArgument($sequencedArgument.sequencedArgument); }
      )?
      RBRACE
      { $namedArgumentList.setEndToken($RBRACE); }
    ;

sequencedArgument returns [SequencedArgument sequencedArgument]
    : compilerAnnotations
      { sequencedArgument = new SequencedArgument(null);
        sequencedArgument.getCompilerAnnotations().addAll($compilerAnnotations.annotations); }
        (
          pa1=positionalArgument
          { if ($pa1.positionalArgument!=null)
                $sequencedArgument.addPositionalArgument($pa1.positionalArgument); }
        |
          sa1=spreadArgument
          { if ($sa1.positionalArgument!=null)
                $sequencedArgument.addPositionalArgument($sa1.positionalArgument); }
        |
          c1=comprehension
          { if ($c1.comprehension!=null)
                $sequencedArgument.addPositionalArgument($c1.comprehension); }
        )
        (
          c=COMMA
          { $sequencedArgument.setEndToken($c); }
          (
            pa2=positionalArgument
            { if ($pa2.positionalArgument!=null)
                  $sequencedArgument.addPositionalArgument($pa2.positionalArgument); 
              sequencedArgument.setEndToken(null); }
          |
            sa2=spreadArgument
            { if ($sa2.positionalArgument!=null)
                  $sequencedArgument.addPositionalArgument($sa2.positionalArgument); 
              sequencedArgument.setEndToken(null); }
          |
            c2=comprehension
            { if ($c2.comprehension!=null)
                $sequencedArgument.addPositionalArgument($c2.comprehension);
              sequencedArgument.setEndToken(null); }
          |
            { displayRecognitionError(getTokenNames(), 
                new MismatchedTokenException(LIDENTIFIER, input)); }
          )
        )* 
    ;

namedArgument returns [NamedArgument namedArgument]
    : compilerAnnotations 
    (  
      namedSpecifiedArgument
      { $namedArgument = $namedSpecifiedArgument.specifiedArgument; }
    |
      namedArgumentDeclaration
      { $namedArgument = $namedArgumentDeclaration.declaration; }
    )
    { if ($namedArgument!=null)
          namedArgument.getCompilerAnnotations().addAll($compilerAnnotations.annotations); }
    ;

namedSpecifiedArgument returns [SpecifiedArgument specifiedArgument]
    : memberName
      { $specifiedArgument = new SpecifiedArgument(null); 
        $specifiedArgument.setIdentifier($memberName.identifier); }
      (
        specifier 
        { $specifiedArgument.setSpecifierExpression($specifier.specifierExpression); }
      )?
      { expecting=SEMICOLON; }
      SEMICOLON
      { $specifiedArgument.setEndToken($SEMICOLON); }
    ;

anonymousArgument returns [SpecifiedArgument namedArgument]
    @init { $namedArgument = new SpecifiedArgument(null); }
    : functionOrExpression
     { SpecifierExpression se = new SpecifierExpression(null);
       se.setExpression($functionOrExpression.expression);
       $namedArgument.setSpecifierExpression(se); }   
      { expecting=SEMICOLON; }
      SEMICOLON
      { $namedArgument.setEndToken($SEMICOLON); }
    ;

objectArgument returns [ObjectArgument declaration]
    : OBJECT_DEFINITION 
      { $declaration = new ObjectArgument($OBJECT_DEFINITION); 
        $declaration.setType(new ValueModifier(null)); }
      memberNameDeclaration
      { $declaration.setIdentifier($memberNameDeclaration.identifier); }
      ( 
        extendedType
        { $declaration.setExtendedType($extendedType.extendedType); } 
      )?
      ( 
        satisfiedTypes
        { $declaration.setSatisfiedTypes($satisfiedTypes.satisfiedTypes); } 
      )?
      (
        classBody
        { $declaration.setClassBody($classBody.classBody); }
      | { displayRecognitionError(getTokenNames(), 
              new MismatchedTokenException(LBRACE, input)); }
        SEMICOLON
        { $declaration.setEndToken($SEMICOLON); }
      )
    ;

voidOrInferredMethodArgument returns [MethodArgument declaration]
    : { $declaration=new MethodArgument(null); }
      (
        VOID_MODIFIER
        { $declaration.setType(new VoidModifier($VOID_MODIFIER)); }
      |
        FUNCTION_MODIFIER
        { $declaration.setType(new FunctionModifier($FUNCTION_MODIFIER)); }
      ) 
      memberNameDeclaration 
      { $declaration.setIdentifier($memberNameDeclaration.identifier); }
      (
        parameters
        { $declaration.addParameterList($parameters.parameterList); }
      )*
      (
        block
        { $declaration.setBlock($block.block); }
      | 
        (
          lazySpecifier
          { $declaration.setSpecifierExpression($lazySpecifier.specifierExpression); }
        )?
        { expecting=SEMICOLON; }
        SEMICOLON
        { expecting=-1; }
        { $declaration.setEndToken($SEMICOLON); }
      )
    ;

inferredGetterArgument returns [AttributeArgument declaration]
    : { $declaration=new AttributeArgument(null); }
      VALUE_MODIFIER 
      { $declaration.setType(new ValueModifier($VALUE_MODIFIER)); }
      memberNameDeclaration 
      { $declaration.setIdentifier($memberNameDeclaration.identifier); }
      (
        block
        { $declaration.setBlock($block.block); }
      | 
        (
          lazySpecifier
          { $declaration.setSpecifierExpression($lazySpecifier.specifierExpression); }
        )?
        { expecting=SEMICOLON; }
        SEMICOLON
        { expecting=-1; }
        { $declaration.setEndToken($SEMICOLON); }
      )
    ;

typedMethodOrGetterArgument returns [TypedArgument declaration]
    @init { MethodArgument marg = new MethodArgument(null);
            AttributeArgument aarg = new AttributeArgument(null); 
            $declaration=aarg; }
    : type 
      { marg.setType($type.type);
        aarg.setType($type.type); }
      memberNameDeclaration
      { marg.setIdentifier($memberNameDeclaration.identifier);
        aarg.setIdentifier($memberNameDeclaration.identifier); }
      ( 
        { $declaration = marg; }
        (
          parameters
          { marg.addParameterList($parameters.parameterList); }
        )+
      )?
      (
        block
        { marg.setBlock($block.block);
          aarg.setBlock($block.block); }
      | 
        (
          lazySpecifier
          { marg.setSpecifierExpression($lazySpecifier.specifierExpression);
            aarg.setSpecifierExpression($lazySpecifier.specifierExpression); }
        )?
        { expecting=SEMICOLON; }
        SEMICOLON
        { expecting=-1; }
        { $declaration.setEndToken($SEMICOLON); }
      )
    ;

untypedMethodOrGetterArgument returns [TypedArgument declaration]
    @init { MethodArgument marg = new MethodArgument(null);
            marg.setType(new FunctionModifier(null));
            AttributeArgument aarg = new AttributeArgument(null);
            aarg.setType(new ValueModifier(null));
            $declaration=aarg; }
    : memberName
      { marg.setIdentifier($memberName.identifier);
        aarg.setIdentifier($memberName.identifier); }
      ( 
        { $declaration = marg; }
        (
          parameters
          { marg.addParameterList($parameters.parameterList); }
        )+
      )?
      lazySpecifier
      { marg.setSpecifierExpression($lazySpecifier.specifierExpression);
        aarg.setSpecifierExpression($lazySpecifier.specifierExpression); }
      { expecting=SEMICOLON; }
      SEMICOLON
      { expecting=-1; }
      { $declaration.setEndToken($SEMICOLON); }
    ;

namedArgumentDeclaration returns [NamedArgument declaration]
    : objectArgument
      { $declaration=$objectArgument.declaration; }
    | typedMethodOrGetterArgument
      { $declaration=$typedMethodOrGetterArgument.declaration; }
    | voidOrInferredMethodArgument
      { $declaration=$voidOrInferredMethodArgument.declaration; }
    | inferredGetterArgument
      { $declaration=$inferredGetterArgument.declaration; }
    | untypedMethodOrGetterArgument
      { $declaration=$untypedMethodOrGetterArgument.declaration; }
    ;

//special rule for syntactic predicate
//to distinguish between a named argument
//and a sequenced argument
namedArgumentStart
    : compilerAnnotations 
      (specificationStart | declarationStart)
    ;

namedAnnotationArgumentsStart
    : LBRACE ((namedArgumentStart)=>namedArgumentStart | iterableArgumentStart | RBRACE)
    ;

iterableArgumentStart
    : compilerAnnotations expression (COMMA|RBRACE)
    ;

//special rule for syntactic predicates
specificationStart
    : LIDENTIFIER parameters* (SPECIFY|COMPUTE)
    ;

parExpression returns [Expression expression] 
    : LPAREN 
      { $expression = new Expression($LPAREN); }
      functionOrExpression
      { if ($functionOrExpression.expression!=null)
            $expression.setTerm($functionOrExpression.expression.getTerm()); }
      RPAREN
      { $expression.setEndToken($RPAREN); }
    ;
        
positionalArguments returns [PositionalArgumentList positionalArgumentList]
    : LPAREN 
      { $positionalArgumentList = new PositionalArgumentList($LPAREN); }
      (
        sa=sequencedArgument
        { if ($sa.sequencedArgument!=null) 
              for (PositionalArgument pa: $sa.sequencedArgument.getPositionalArguments())
                  $positionalArgumentList.addPositionalArgument(pa); }
      )?
      RPAREN
      { $positionalArgumentList.setEndToken($RPAREN); }
    ;

positionalArgument returns [ListedArgument positionalArgument]
    : { $positionalArgument = new ListedArgument(null); }
      functionOrExpression
      { $positionalArgument.setExpression($functionOrExpression.expression); }
    ;

spreadArgument returns [SpreadArgument positionalArgument]
    : PRODUCT_OP
      { $positionalArgument = new SpreadArgument($PRODUCT_OP); }
      unionExpression
      { Expression e = new Expression(null);
        e.setTerm($unionExpression.term);
        $positionalArgument.setExpression(e); }
    ;

anonParametersStart
    : LPAREN (compilerAnnotations annotatedDeclarationStart | RPAREN)
    ;

nonemptyParametersStart
    : LPAREN compilerAnnotations annotatedDeclarationStart
    ;

functionOrExpression returns [Expression expression]
    : (FUNCTION_MODIFIER|VOID_MODIFIER|anonParametersStart) =>
      f=anonymousFunction
      { $expression = $f.expression; }
    | e=expression
      { $expression = $e.expression; }
    ;

anonymousFunction returns [Expression expression]
    @init { FunctionArgument fa = new FunctionArgument(null);
            fa.setType(new FunctionModifier(null)); 
            Expression e = new Expression(null);
            e.setTerm(fa); }
    : (
        FUNCTION_MODIFIER
        { fa.setType(new FunctionModifier($FUNCTION_MODIFIER)); }
      |
        VOID_MODIFIER
        { fa.setType(new VoidModifier($VOID_MODIFIER)); }
      )?
      { $expression=e; }
      p1=parameters
      { fa.addParameterList($p1.parameterList); }
      ( 
        //(anonParametersStart)=> 
        p2=parameters
        { fa.addParameterList($p2.parameterList); }
      )*
      ( 
        COMPUTE
        fe=functionOrExpression
        { fa.setExpression($fe.expression); }
      |
        block
        { fa.setBlock($block.block); }
      )
    ;

comprehension returns [Comprehension comprehension]
    @init { $comprehension = new Comprehension(null); }
    : forComprehensionClause
      { $comprehension.setForComprehensionClause($forComprehensionClause.comprehensionClause); }
    ;

comprehensionClause returns [ComprehensionClause comprehensionClause]
    : forComprehensionClause 
      { $comprehensionClause = $forComprehensionClause.comprehensionClause; }
    | ifComprehensionClause 
      { $comprehensionClause = $ifComprehensionClause.comprehensionClause; }
    | expressionComprehensionClause 
      { $comprehensionClause = $expressionComprehensionClause.comprehensionClause; }
    ;

expressionComprehensionClause returns [ExpressionComprehensionClause comprehensionClause]
    : functionOrExpression
      { $comprehensionClause = new ExpressionComprehensionClause(null);
        $comprehensionClause.setExpression($functionOrExpression.expression); }
    | { displayRecognitionError(getTokenNames(), 
          new MismatchedTokenException(LIDENTIFIER, input)); }
    ;

forComprehensionClause returns [ForComprehensionClause comprehensionClause]
    : FOR_CLAUSE
      { $comprehensionClause = new ForComprehensionClause($FOR_CLAUSE); }
      forIterator
      { $comprehensionClause.setForIterator($forIterator.iterator); }
      comprehensionClause
      { $comprehensionClause.setComprehensionClause($comprehensionClause.comprehensionClause); }
    ;
    
ifComprehensionClause returns [IfComprehensionClause comprehensionClause]
    : IF_CLAUSE
      { $comprehensionClause = new IfComprehensionClause($IF_CLAUSE); }
      conditions
      { $comprehensionClause.setConditionList($conditions.conditionList); }
      comprehensionClause
      { $comprehensionClause.setComprehensionClause($comprehensionClause.comprehensionClause); }
    ;
    
assignmentExpression returns [Term term]
    @init { QualifiedMemberOrTypeExpression qe=null; }
    : ee1=thenElseExpression
      { $term = $ee1.term; }
      (
        assignmentOperator 
        { $assignmentOperator.operator.setLeftTerm($term);
          $term = $assignmentOperator.operator; }
        ee2=functionOrExpression
        { if ($ee2.expression!=null)
              $assignmentOperator.operator.setRightTerm($ee2.expression.getTerm()); }
      | memberReference
        { qe = new QualifiedMemberExpression(null);
          Expression e = new Expression(null);
          e.setTerm($term);
          qe.setPrimary(e);
          qe.setMemberOperator(new MemberOp(null));
          qe.setIdentifier($memberReference.identifier);
          qe.setTypeArguments( new InferredTypeArguments(null) );
          if ($memberReference.typeArgumentList!=null)
              qe.setTypeArguments($memberReference.typeArgumentList); 
          $term = qe; }
        (
        positionalArgument
        { InvocationExpression ie = new InvocationExpression(null);
          ie.setPrimary(qe);
          PositionalArgumentList al = new PositionalArgumentList(null);
          al.addPositionalArgument($positionalArgument.positionalArgument); 
          ie.setPositionalArgumentList(al);
          $term = ie; }
        )?
      )?
    ;

assignmentOperator returns [AssignmentOp operator]
    : SPECIFY { $operator = new AssignOp($SPECIFY); }
    //| APPLY_OP 
    | ADD_SPECIFY { $operator = new AddAssignOp($ADD_SPECIFY); }
    | SUBTRACT_SPECIFY { $operator = new SubtractAssignOp($SUBTRACT_SPECIFY); }
    | MULTIPLY_SPECIFY { $operator = new MultiplyAssignOp($MULTIPLY_SPECIFY); }
    | DIVIDE_SPECIFY { $operator = new DivideAssignOp($DIVIDE_SPECIFY); }
    | REMAINDER_SPECIFY { $operator = new RemainderAssignOp($REMAINDER_SPECIFY); }
    | INTERSECT_SPECIFY { $operator = new IntersectAssignOp($INTERSECT_SPECIFY); }
    | UNION_SPECIFY { $operator = new UnionAssignOp($UNION_SPECIFY); }
    | COMPLEMENT_SPECIFY { $operator = new ComplementAssignOp($COMPLEMENT_SPECIFY); }
    | AND_SPECIFY { $operator = new AndAssignOp($AND_SPECIFY); }
    | OR_SPECIFY { $operator = new OrAssignOp($OR_SPECIFY); }
    //| DEFAULT_SPECIFY { $operator = new DefaultAssignOp($DEFAULT_SPECIFY); }
    ;

thenElseExpression returns [Term term]
    : de1=disjunctionExpression
      { $term = $de1.term; }
      (
        thenElseOperator
        { $thenElseOperator.operator.setLeftTerm($term);
          $term = $thenElseOperator.operator; }
        de2=disjunctionExpression
        { $thenElseOperator.operator.setRightTerm($de2.term); }
      )*
    //TODO: enable this to add support for if (...) and 
    //      given (...) expressions
    //TODO: when enabling this, we'll need something
    //      to distinguish between "if (...) then" and 
    //      the control structure "if (...) { ... }"
    /*| 
      ( 
        IF_CLAUSE LPAREN ( existsCondition | nonemptyCondition | isCondition ) RPAREN
      | 
        TYPE_CONSTRAINT LPAREN specifiedConditionVariable RPAREN 
      )+
      THEN_CLAUSE disjunctionExpression
      (ELSE_CLAUSE disjunctionExpression)?*/
    ;

thenElseOperator returns [BinaryOperatorExpression operator]
    : ELSE_CLAUSE 
      { $operator = new DefaultOp($ELSE_CLAUSE); }
    | THEN_CLAUSE
      { $operator = new ThenOp($THEN_CLAUSE); }
    ;

disjunctionExpression returns [Term term]
    : me1=conjunctionExpression
      { $term = $me1.term; }
      (
        disjunctionOperator 
        { $disjunctionOperator.operator.setLeftTerm($term);
          $term = $disjunctionOperator.operator; }
        me2=conjunctionExpression
        { $disjunctionOperator.operator.setRightTerm($me2.term); }
      )*
    ;

disjunctionOperator returns [OrOp operator]
    : OR_OP 
      { $operator = new OrOp($OR_OP); }
    ;

conjunctionExpression returns [Term term]
    : me1=logicalNegationExpression
      { $term = $me1.term; }
      (
        conjunctionOperator 
        { $conjunctionOperator.operator.setLeftTerm($term);
          $term = $conjunctionOperator.operator; }
        me2=logicalNegationExpression
        { $conjunctionOperator.operator.setRightTerm($me2.term); }
      )*
    ;

conjunctionOperator returns [AndOp operator]
    : AND_OP 
      { $operator = new AndOp($AND_OP); }
    ;

logicalNegationExpression returns [Term term]
    : notOperator 
      { $term = $notOperator.operator; }
      le=logicalNegationExpression
      { $notOperator.operator.setTerm($le.term); }
    | equalityExpression
      { $term = $equalityExpression.term; }
    ;

notOperator returns [NotOp operator]
    : NOT_OP 
      { $operator = new NotOp($NOT_OP); }
    ;

equalityExpression returns [Term term]
    : ee1=comparisonExpression
      { $term = $ee1.term; }
      (
        equalityOperator 
        { $equalityOperator.operator.setLeftTerm($term);
          $term = $equalityOperator.operator; }
        ee2=comparisonExpression
        { $equalityOperator.operator.setRightTerm($ee2.term); }
      )?
    ;

equalityOperator returns [BinaryOperatorExpression operator]
    : EQUAL_OP 
      { $operator = new EqualOp($EQUAL_OP); }
    | NOT_EQUAL_OP
      { $operator = new NotEqualOp($NOT_EQUAL_OP); }
    | IDENTICAL_OP
      { $operator = new IdenticalOp($IDENTICAL_OP); }
    ;

comparisonExpression returns [Term term]
    : ee1=existenceEmptinessExpression
      { $term = $ee1.term; }
      (
        comparisonOperator 
        { $comparisonOperator.operator.setLeftTerm($term);
          $term = $comparisonOperator.operator; }
        ee2=existenceEmptinessExpression
        { $comparisonOperator.operator.setRightTerm($ee2.term); }
      | to1=typeOperator
        { $to1.operator.setTerm($ee1.term); 
          $term = $to1.operator;}
        t1=type
        { $to1.operator.setType($t1.type); }
      )?
    /*| to2=typeOperator
      { $term = $to2.operator; }
      t2=type
      { $to2.operator.setType($t2.type); }
      ee3=existenceEmptinessExpression
      { $to2.operator.setTerm($ee3.term); }*/
    ;

comparisonOperator returns [BinaryOperatorExpression operator]
    : COMPARE_OP 
      { $operator = new CompareOp($COMPARE_OP); }
    | SMALL_AS_OP
      { $operator = new SmallAsOp($SMALL_AS_OP); }
    | LARGE_AS_OP
      { $operator = new LargeAsOp($LARGE_AS_OP); }
    | LARGER_OP
      { $operator = new LargerOp($LARGER_OP); }
    | SMALLER_OP
      { $operator = new SmallerOp($SMALLER_OP); }
    | IN_OP
      { $operator = new InOp($IN_OP); }
    ;

typeOperator returns [TypeOperatorExpression operator]
    : IS_OP
      { $operator = new IsOp($IS_OP); }
    | EXTENDS
      { $operator = new Extends($EXTENDS); }
    | SATISFIES
      { $operator = new Satisfies($SATISFIES); }
    | CASE_TYPES
      { $operator = new OfOp($CASE_TYPES); }
    ;

existenceEmptinessExpression returns [Term term]
    : de1=entryRangeExpression
      { $term = $de1.term; }
      (
        eno1=existsNonemptyOperator
        { $term = $eno1.operator;
          $eno1.operator.setTerm($de1.term); }
      )?
    /*| eno2=existsNonemptyOperator
      { $term = $eno2.operator; }
      de2=rangeIntervalEntryExpression
      { $eno2.operator.setTerm($de2.term); }*/
    ;

existsNonemptyOperator returns [UnaryOperatorExpression operator]
    : EXISTS 
      { $operator = new Exists($EXISTS); }
    | NONEMPTY
      { $operator = new Nonempty($NONEMPTY); }
    ;

entryRangeExpression returns [Term term]
    : ae1=additiveExpression
      { $term = $ae1.term; }
      (
        rangeIntervalEntryOperator 
        { $rangeIntervalEntryOperator.operator.setLeftTerm($term);
          $term = $rangeIntervalEntryOperator.operator; }
        ae2=additiveExpression
        { $rangeIntervalEntryOperator.operator.setRightTerm($ae2.term); }
      )?
    ;

rangeIntervalEntryOperator returns [BinaryOperatorExpression operator]
    : RANGE_OP 
      { $operator = new RangeOp($RANGE_OP); }
    | SEGMENT_OP
      { $operator = new SegmentOp($SEGMENT_OP); }
    | ENTRY_OP
      { $operator = new EntryOp($ENTRY_OP); }
    ;

additiveExpression returns [Term term]
    : me1=multiplicativeExpression
      { $term = $me1.term; }
      (
        additiveOperator 
        { $additiveOperator.operator.setLeftTerm($term);
          $term = $additiveOperator.operator; }
        me2=multiplicativeExpression
        { $additiveOperator.operator.setRightTerm($me2.term); }
      )*
    ;

additiveOperator returns [BinaryOperatorExpression operator]
    : SUM_OP 
      { $operator = new SumOp($SUM_OP); }
    | DIFFERENCE_OP
      { $operator = new DifferenceOp($DIFFERENCE_OP); }
    ;

multiplicativeExpression returns [Term term]
    : ue1=unionExpression
      { $term = $ue1.term; }
      (
        multiplicativeOperator 
        { $multiplicativeOperator.operator.setLeftTerm($term);
          $term = $multiplicativeOperator.operator; }
        ue2=unionExpression
        { $multiplicativeOperator.operator.setRightTerm($ue2.term); }
      )*
    ;

multiplicativeOperator returns [BinaryOperatorExpression operator]
    : PRODUCT_OP 
      { $operator = new ProductOp($PRODUCT_OP); }
    | QUOTIENT_OP
      { $operator = new QuotientOp($QUOTIENT_OP); }
    | REMAINDER_OP
      { $operator = new RemainderOp($REMAINDER_OP); }
    ;

unionExpression returns [Term term]
    : ie1=intersectionExpression
      { $term = $ie1.term; }
      (
        unionOperator 
        { $unionOperator.operator.setLeftTerm($term);
          $term = $unionOperator.operator; }
        ie2=intersectionExpression
        { $unionOperator.operator.setRightTerm($ie2.term); }
      )*
    ;
    
unionOperator returns [BinaryOperatorExpression operator]
    : UNION_OP
      { $operator = new UnionOp($UNION_OP); }
    | COMPLEMENT_OP
      { $operator = new ComplementOp($COMPLEMENT_OP); }
    ;

intersectionExpression returns [Term term]
    : ne1=negationComplementExpression
      { $term = $ne1.term; }
      (
        intersectionOperator 
        { $intersectionOperator.operator.setLeftTerm($term);
          $term = $intersectionOperator.operator; }
        ne2=negationComplementExpression
        { $intersectionOperator.operator.setRightTerm($ne2.term); }
      )*
    ;
    
intersectionOperator returns [BinaryOperatorExpression operator]
    : INTERSECTION_OP
      { $operator = new IntersectionOp($INTERSECTION_OP); }
    ;

negationComplementExpression returns [Term term]
    : unaryMinusOrComplementOperator 
      { $term = $unaryMinusOrComplementOperator.operator; }
      ne=negationComplementExpression
      { $unaryMinusOrComplementOperator.operator.setTerm($ne.term); }
    | exponentiationExpression
      { $term = $exponentiationExpression.term; }
    ;

unaryMinusOrComplementOperator returns [UnaryOperatorExpression operator]
    : DIFFERENCE_OP 
      { $operator = new NegativeOp($DIFFERENCE_OP); }
    | SUM_OP
      { $operator = new PositiveOp($SUM_OP); }
    ;

exponentiationExpression returns [Term term]
    : incrementDecrementExpression
      { $term = $incrementDecrementExpression.term; }
      (
        exponentiationOperator
        { $exponentiationOperator.operator.setLeftTerm($term);
          $term = $exponentiationOperator.operator; }
        ee=exponentiationExpression
        { $exponentiationOperator.operator.setRightTerm($ee.term); }
      )?
    ;

exponentiationOperator returns [PowerOp operator]
    : POWER_OP 
      { $operator = new PowerOp($POWER_OP); }
    ;

incrementDecrementExpression returns [Term term]
    : prefixOperator
      { $term = $prefixOperator.operator; }
      ie=incrementDecrementExpression
      { $prefixOperator.operator.setTerm($ie.term); }
    | postfixIncrementDecrementExpression
      { $term = $postfixIncrementDecrementExpression.term; }
    ;

prefixOperator returns [PrefixOperatorExpression operator]
    : DECREMENT_OP 
      { $operator = new DecrementOp($DECREMENT_OP); }
    | INCREMENT_OP 
      { $operator = new IncrementOp($INCREMENT_OP); }
    ;

postfixIncrementDecrementExpression returns [Term term]
    : primary 
      { $term = $primary.primary; } 
      (
        postfixOperator
        { $postfixOperator.operator.setTerm($term);
          $term = $postfixOperator.operator; }
      )*
    ;

postfixOperator returns [PostfixOperatorExpression operator]
    : DECREMENT_OP 
      { $operator = new PostfixDecrementOp($DECREMENT_OP); }
    | INCREMENT_OP 
      { $operator = new PostfixIncrementOp($INCREMENT_OP); }
    ;

selfReference returns [Atom atom]
    : THIS
      { $atom = new This($THIS); }
    | SUPER 
      { $atom = new Super($SUPER); }
    | OUTER
      { $atom = new Outer($OUTER); }
    | PACKAGE
      { $atom = new Package($PACKAGE); }
    ;
    
nonstringLiteral returns [Literal literal]
    : NATURAL_LITERAL 
      { $literal = new NaturalLiteral($NATURAL_LITERAL); }
    | FLOAT_LITERAL 
      { $literal = new FloatLiteral($FLOAT_LITERAL); }
    | CHAR_LITERAL 
      { $literal = new CharLiteral($CHAR_LITERAL); }
    ;

stringLiteral returns [StringLiteral stringLiteral]
    : STRING_LITERAL 
      { $stringLiteral = new StringLiteral($STRING_LITERAL); }
    | VERBATIM_STRING
      { $stringLiteral = new StringLiteral($VERBATIM_STRING); }
    ;

stringExpression returns [Atom atom]
    @init { StringTemplate st=null; }
    : sl1=stringLiteral
      { $atom=$sl1.stringLiteral; }
    | STRING_START
      { st = new StringTemplate(null);
        st.addStringLiteral(new StringLiteral($STRING_START));
        $atom=st; }
      e1=expression
      { if ($e1.expression!=null) 
            st.addExpression($e1.expression); }
      (
        STRING_MID
        { st.addStringLiteral(new StringLiteral($STRING_MID)); }
        e2=expression
        { if ($e2.expression!=null) 
              st.addExpression($e2.expression); }
      )*
      STRING_END
      { st.addStringLiteral(new StringLiteral($STRING_END)); }
    ;

typeArguments returns [TypeArgumentList typeArgumentList]
    : SMALLER_OP
      { $typeArgumentList = new TypeArgumentList($SMALLER_OP); }
      ta1=type
      { if ($ta1.type!=null)
            $typeArgumentList.addType($ta1.type); }
      (
        c=COMMA
        { $typeArgumentList.setEndToken($c); }
        (
          ta2=type
          { if ($ta2.type!=null)
                $typeArgumentList.addType($ta2.type); 
            $typeArgumentList.setEndToken(null); }
          | { displayRecognitionError(getTokenNames(), 
                new MismatchedTokenException(UIDENTIFIER, input)); }
        )
      )* 
      LARGER_OP
      { $typeArgumentList.setEndToken($LARGER_OP); }
    ;

variadicType returns [Type type]
    : (unionType (PRODUCT_OP|SUM_OP))=>
      at=unionType
      (
        PRODUCT_OP
        { SequencedType st = new SequencedType(null);
          st.setType($at.type); 
          st.setEndToken($PRODUCT_OP);
          $type = st; }
      |
        SUM_OP
        { SequencedType st = new SequencedType(null);
          st.setType($at.type); 
          st.setEndToken($SUM_OP);
          st.setAtLeastOne(true);
          $type = st; }
      )
    |
      t=type
      { $type = $t.type; }
      (
        SPECIFY
        { DefaultedType st = new DefaultedType(null);
          st.setType($t.type); 
          st.setEndToken($SPECIFY);
          $type = st; }
      )?
    ;

tupleType returns [TupleType type]
    : LBRACKET
      { $type = new TupleType($LBRACKET); }
      (
        t1=variadicType
        { $type.addElementType($t1.type); }
        (
          c=COMMA
          { $type.setEndToken($c); }
          t2=variadicType
          { $type.addElementType($t2.type);
            $type.setEndToken(null); }
        )*
      )?
      RBRACKET
      { $type.setEndToken($RBRACKET); }
    ;

groupedType returns [StaticType type]
    : SMALLER_OP
      t=type
      { $type=$t.type; }
      LARGER_OP
    ;

iterableType returns [IterableType type]
   : LBRACE
     { $type = new IterableType($LBRACE); }
     t=variadicType
     { $type.setElementType($t.type); }
     RBRACE
     { $type.setEndToken($RBRACE); }
   ;

type returns [StaticType type]
    @init { EntryType bt=null; }
    : t1=unionType
      { $type=$t1.type; }
      (
        ENTRY_OP
        { bt=new EntryType(null);
          bt.setKeyType($type);
          bt.setEndToken($ENTRY_OP); 
          $type=bt; }
        (
          t2=unionType
          { bt.setValueType($t2.type);
            bt.setEndToken(null); }
//        | { displayRecognitionError(getTokenNames(), 
//                new MismatchedTokenException(UIDENTIFIER, input)); }
        )
      )?
    ;

unionType returns [StaticType type]
    @init { UnionType ut=null; }
    : it1=intersectionType
      { $type = $it1.type;
        ut = new UnionType(null);
        ut.addStaticType($type); }
      ( 
        (
          u=UNION_OP
          { ut.setEndToken($u); }
          (
            it2=intersectionType
            { ut.addStaticType($it2.type);
              ut.setEndToken(null); }
//          | { displayRecognitionError(getTokenNames(), 
//                new MismatchedTokenException(UIDENTIFIER, input)); }
          )
        )+
        { $type = ut; }
      )?
    ;

intersectionType returns [StaticType type]
    @init { IntersectionType it=null; }
    : at1=abbreviatedType
      { $type = $at1.type;
        it = new IntersectionType(null);
        it.addStaticType($type); }
      ( 
        (
          i=INTERSECTION_OP
          { it.setEndToken($i); }
          (
            at2=abbreviatedType
            { it.addStaticType($at2.type);
              it.setEndToken(null); }
//          | { displayRecognitionError(getTokenNames(), 
//                new MismatchedTokenException(UIDENTIFIER, input)); }
          )
        )+
        { $type = it; }
      )?
    ;

qualifiedOrTupleType returns [StaticType type]
    : qualifiedType 
      { $type=$qualifiedType.type; }
    | tupleType 
      { $type=$tupleType.type; }
    | iterableType
      { $type=$iterableType.type; }
    | groupedType
      { $type=$groupedType.type; }
    ;

/*typeAbbreviationStart
    : DEFAULT_OP
    | ARRAY
    | LPAREN tupleElementType? (COMMA|RPAREN)
    ;*/

abbreviatedType returns [StaticType type]
    @init { FunctionType bt=null; }
    : qualifiedOrTupleType
      { $type=$qualifiedOrTupleType.type; }
      (
      //syntactic predicate to resolve an
      //ambiguity in the grammar of the
      //prefix "is Type" operator
      //(typeAbbreviationStart)=>
      (
        OPTIONAL 
        { OptionalType ot = new OptionalType(null);
          ot.setDefiniteType($type);
          ot.setEndToken($OPTIONAL);
          $type=ot; }
      | LBRACKET RBRACKET 
        { SequenceType st = new SequenceType(null);
          st.setElementType($type);
          st.setEndToken($LBRACKET);
          st.setEndToken($RBRACKET);
          $type=st; }
      | LPAREN
        { bt = new FunctionType(null);
          bt.setEndToken($LPAREN);
          bt.setReturnType($type);
          $type=bt; }
          (
            t1=variadicType
            { if ($t1.type!=null)
                  bt.addArgumentType($t1.type); }
            (
              COMMA
              { bt.setEndToken($COMMA); }
              t2=variadicType
              { if ($t2.type!=null)
                    bt.addArgumentType($t2.type); }
            )*
          )?
        RPAREN
        { bt.setEndToken($RPAREN); }
      )
      )*
    ;
    
qualifiedType returns [SimpleType type]
    : supertypeQualifier?
      ot=typeNameWithArguments
      { BaseType bt = new BaseType(null);
        bt.setIdentifier($ot.identifier);
        if ($ot.typeArgumentList!=null)
            bt.setTypeArgumentList($ot.typeArgumentList);
        if ($supertypeQualifier.qualifier!=null)
            bt.setSupertypeQualifier($supertypeQualifier.qualifier);
        $type=bt; }
      (
        MEMBER_OP 
        it=typeNameWithArguments
        { QualifiedType qt = new QualifiedType($MEMBER_OP);
          qt.setIdentifier($it.identifier);
          if ($it.typeArgumentList!=null)
              qt.setTypeArgumentList($it.typeArgumentList);
          qt.setOuterType($type);
          $type=qt; }
      )*
    ;

typeNameWithArguments returns [Identifier identifier, TypeArgumentList typeArgumentList]
    : typeName
      { $identifier = $typeName.identifier; } 
      (
        typeArguments
        { $typeArgumentList = $typeArguments.typeArgumentList; }
      )?
    ;
    
annotations returns [AnnotationList annotationList]
    : { $annotationList = new AnnotationList(null); }
      (
          stringLiteral
          { if ($stringLiteral.stringLiteral.getToken().getType()==VERBATIM_STRING)
                $stringLiteral.stringLiteral.getToken().setType(AVERBATIM_STRING);
            else
                $stringLiteral.stringLiteral.getToken().setType(ASTRING_LITERAL);
            AnonymousAnnotation aa = new AnonymousAnnotation(null);
            aa.setStringLiteral($stringLiteral.stringLiteral);
            $annotationList.setAnonymousAnnotation(aa); }
      )?
      (
        annotation 
        { $annotationList.addAnnotation($annotation.annotation); }
      )*
    ;

annotation returns [Annotation annotation]
    : annotationName
      { $annotation = new Annotation(null);
        BaseMemberExpression bme = new BaseMemberExpression(null);
        bme.setIdentifier($annotationName.identifier);
        bme.setTypeArguments( new InferredTypeArguments(null) );
        $annotation.setPrimary(bme); }
      annotationArguments
      { if ($annotationArguments.argumentList instanceof PositionalArgumentList)
            $annotation.setPositionalArgumentList((PositionalArgumentList)$annotationArguments.argumentList);
        if ($annotationArguments.argumentList instanceof NamedArgumentList)
            $annotation.setNamedArgumentList((NamedArgumentList)$annotationArguments.argumentList); }
    ;

annotationArguments returns [ArgumentList argumentList]
    : positionalArguments 
      { $argumentList = $positionalArguments.positionalArgumentList; }
    | (namedAnnotationArgumentsStart) =>
      namedArguments
      { $argumentList = $namedArguments.namedArgumentList; }
    | literalArguments
      { $argumentList=$literalArguments.argumentList; }
    ;

literalArguments returns [PositionalArgumentList argumentList]
    : { $argumentList = new PositionalArgumentList(null); }
      (
        literalArgument
        { $argumentList.addPositionalArgument($literalArgument.positionalArgument); }
      )*
    ;
    
literalArgument returns [ListedArgument positionalArgument]
    : nonstringLiteral
      { $positionalArgument = new ListedArgument(null);
        Expression e = new Expression(null);
        e.setTerm($nonstringLiteral.literal);
        $positionalArgument.setExpression(e); }
    | stringLiteral
      { $positionalArgument = new ListedArgument(null);
        Expression e = new Expression(null);
        e.setTerm($stringLiteral.stringLiteral);
        $positionalArgument.setExpression(e); 
         if ($stringLiteral.stringLiteral.getToken().getType()==VERBATIM_STRING)
             $stringLiteral.stringLiteral.getToken().setType(AVERBATIM_STRING);
         else
             $stringLiteral.stringLiteral.getToken().setType(ASTRING_LITERAL); }
    ;

prefixOperatorStart
    : DIFFERENCE_OP
    | INCREMENT_OP 
    | DECREMENT_OP 
    | COMPLEMENT_OP
    ;
    
compilerAnnotations returns [List<CompilerAnnotation> annotations]
    : { $annotations = new ArrayList<CompilerAnnotation>(); }
    (
      compilerAnnotation
      { $annotations.add($compilerAnnotation.annotation); }
    )*
    ;
    
compilerAnnotation returns [CompilerAnnotation annotation]
    : COMPILER_ANNOTATION 
      { $annotation=new CompilerAnnotation($COMPILER_ANNOTATION); }
      annotationName 
      { $annotation.setIdentifier($annotationName.identifier); }
      ( 
          SEGMENT_OP
          stringLiteral
          { $annotation.setStringLiteral($stringLiteral.stringLiteral); }
      )?
    ;

conditions returns [ConditionList conditionList]
    : LPAREN
      { $conditionList = new ConditionList($LPAREN); }
      (
      c1=condition
      { if ($c1.condition!=null) 
            $conditionList.addCondition($c1.condition); }
      ( c=COMMA 
        { $conditionList.setEndToken($c); }
        (
          c2=condition 
          { if ($c2.condition!=null) 
                $conditionList.addCondition($c2.condition);
            $conditionList.setEndToken(null); }
        | { displayRecognitionError(getTokenNames(), 
              new MismatchedTokenException(LIDENTIFIER, input)); } //TODO: sometimes it should be RPAREN!
        )
      )*
      )?
      RPAREN
      { $conditionList.setEndToken($RPAREN); }
    ;

condition returns [Condition condition]
    : (EXISTS)=>existsCondition
      { $condition=$existsCondition.condition; }
    | (NONEMPTY)=>nonemptyCondition
      { $condition=$nonemptyCondition.condition; }
    | (NOT_OP? IS_OP)=>isCondition 
      { $condition=$isCondition.condition; }
    | (SATISFIES)=>satisfiesCondition
      { $condition=$satisfiesCondition.condition; }
    | booleanCondition
      { $condition=$booleanCondition.condition; }
    ;
    
booleanCondition returns [BooleanCondition condition]
    : { $condition = new BooleanCondition(null); }
      expression
      { $condition.setExpression($expression.expression); }
    ;
    
existsCondition returns [Condition condition]
    @init { ExistsCondition ec = null; }
    : (EXISTS compilerAnnotations (declarationStart|specificationStart)) =>
      e2=EXISTS 
      { ec = new ExistsCondition($e2); 
        $condition = ec; }
      specifiedVariable 
      { ec.setVariable($specifiedVariable.variable); }
    | //(EXISTS LIDENTIFIER (RPAREN|COMMA)) =>
      e1=EXISTS
      { ec = new ExistsCondition($e1); 
        $condition = ec; }
      impliedVariable
      { ec.setVariable($impliedVariable.variable); }
    ;
    
nonemptyCondition returns [Condition condition]
    @init { NonemptyCondition nc = null; }
    : (NONEMPTY compilerAnnotations (declarationStart|specificationStart)) =>
      n2=NONEMPTY 
      { nc = new NonemptyCondition($n2); 
        $condition = nc; }
      specifiedVariable 
      { nc.setVariable($specifiedVariable.variable); }
    | //(NONEMPTY LIDENTIFIER (RPAREN|COMMA)) =>
      n1=NONEMPTY 
      { nc = new NonemptyCondition($n1); 
        $condition = nc; }
      impliedVariable 
      { nc.setVariable($impliedVariable.variable); }
    ;

isCondition returns [Condition condition]
    @init { IsCondition ic = null;
            boolean not = false; }
    : (NOT_OP? IS_OP type LIDENTIFIER SPECIFY) =>
      (n2=NOT_OP { not=true; })?
      i2=IS_OP 
      { ic = new IsCondition($i2);
        ic.setNot(not); 
        $condition = ic; }
      t2=type
      { ic.setType($t2.type);
        Variable v = new Variable(null);
        v.setType(new ValueModifier(null)); 
        ic.setVariable(v); }
      memberName
      { ic.getVariable().setIdentifier($memberName.identifier); }
      specifier
      { ic.getVariable().setSpecifierExpression($specifier.specifierExpression); }
    | //(NOT_OP? IS_OP type LIDENTIFIER (RPAREN|COMMA)) =>
      (n1=NOT_OP { not=true; })?
      i1=IS_OP
      { ic = new IsCondition($i1); 
        ic.setNot(not);
        $condition = ic; }
      t1=type
      { ic.setType($t1.type); }
      impliedVariable 
      { ic.setVariable($impliedVariable.variable); }
    ;

satisfiesCondition returns [SatisfiesCondition condition]
    : SATISFIES 
      { $condition = new SatisfiesCondition($SATISFIES); }
      (t1=qualifiedType 
      { $condition.setLeftType($t1.type); }
      t2=qualifiedType 
      { $condition.setRightType($t2.type); })?
    ;

controlStatement returns [ControlStatement controlStatement]
    : ifElse 
      { $controlStatement=$ifElse.statement; }
    | switchCaseElse 
      { $controlStatement=$switchCaseElse.statement; }
    | whileLoop 
      { $controlStatement=$whileLoop.statement; }
    | forElse 
      { $controlStatement=$forElse.statement; }
    | tryCatchFinally
      { $controlStatement=$tryCatchFinally.statement; }
    | dynamic
      { $controlStatement=$dynamic.statement; }
    ;

controlBlock returns [Block block]
    : ( (LBRACE)=> b=block
        { $block=$b.block; }
      | { displayRecognitionError(getTokenNames(), 
                new MismatchedTokenException(LBRACE, input)); }
      )
    ;

dynamic returns [DynamicStatement statement]
    @init { DynamicClause dc = null; }
    : { $statement=new DynamicStatement(null); }
      DYNAMIC 
      { dc = new DynamicClause($DYNAMIC);
        $statement.setDynamicClause(dc); }
      controlBlock
      { dc.setBlock($controlBlock.block); }
    ;

ifElse returns [IfStatement statement]
    : { $statement=new IfStatement(null); }
      ifBlock 
      { $statement.setIfClause($ifBlock.clause); }
      ( 
        elseBlock
        { $statement.setElseClause($elseBlock.clause); }
      )?
    ;

ifBlock returns [IfClause clause]
    : IF_CLAUSE 
      { $clause = new IfClause($IF_CLAUSE); }
      conditions
      { $clause.setConditionList($conditions.conditionList); }
      controlBlock
      { $clause.setBlock($controlBlock.block); }
    ;

elseBlock returns [ElseClause clause]
    : ELSE_CLAUSE 
      { $clause = new ElseClause($ELSE_CLAUSE); }
      (
        elseIf 
        { $clause.setBlock($elseIf.block); }
      | 
        block
        { $clause.setBlock($block.block); }
      )
    ;

elseIf returns [Block block]
    : ifElse
      { $block = new Block(null);
        $block.addStatement($ifElse.statement); }
    ;

switchCaseElse returns [SwitchStatement statement]
    : { $statement = new SwitchStatement(null); }
      switchHeader 
      { $statement.setSwitchClause($switchHeader.clause); }
      cases
      { $statement.setSwitchCaseList($cases.switchCaseList);
        Expression ex = $switchHeader.clause.getExpression();
        if (ex!=null && ex.getTerm() instanceof BaseMemberExpression) {
          Identifier id = ((BaseMemberExpression) ex.getTerm()).getIdentifier();
          for (CaseClause cc: $cases.switchCaseList.getCaseClauses()) {
            CaseItem item = cc.getCaseItem();
            if (item instanceof IsCase) {
              IsCase ic = (IsCase) item;
              Variable v = new Variable(null);
              v.setType(new SyntheticVariable(null));
              v.setIdentifier(id);
              SpecifierExpression se = new SpecifierExpression(null);
              Expression e = new Expression(null);
              BaseMemberExpression bme = new BaseMemberExpression(null);
              bme.setIdentifier(id);
              bme.setTypeArguments( new InferredTypeArguments(null) );
              e.setTerm(bme);
              se.setExpression(e);
              v.setSpecifierExpression(se);
              ic.setVariable(v);
            }
          } 
        } 
      }
    ;

switchHeader returns [SwitchClause clause]
    : SWITCH_CLAUSE 
      { $clause = new SwitchClause($SWITCH_CLAUSE); }
      LPAREN 
      (
      expression 
      { $clause.setExpression($expression.expression); }
      )?
      RPAREN
    ;

cases returns [SwitchCaseList switchCaseList]
    : { $switchCaseList = new SwitchCaseList(null); }
      (
        caseBlock
        { $switchCaseList.addCaseClause($caseBlock.clause); }
      )+
      (
        defaultCaseBlock
        { $switchCaseList.setElseClause($defaultCaseBlock.clause); }
      )?
    ;
    
caseBlock returns [CaseClause clause]
    : CASE_CLAUSE 
      { $clause = new CaseClause($CASE_CLAUSE); }
      LPAREN 
      (
      caseItem
      { $clause.setCaseItem($caseItem.item); }
      )?
      RPAREN 
      block
      { $clause.setBlock($block.block); }
    ;

defaultCaseBlock returns [ElseClause clause]
    : ELSE_CLAUSE 
      { $clause = new ElseClause($ELSE_CLAUSE); }
      block
      { $clause.setBlock($block.block); }
    ;

caseItem returns [CaseItem item]
    : (IS_OP)=>isCaseCondition 
      { $item=$isCaseCondition.item; }
    | (SATISFIES)=>satisfiesCaseCondition
      { $item=$satisfiesCaseCondition.item; }
    | matchCaseCondition
      { $item=$matchCaseCondition.item; }
    ;

matchCaseCondition returns [MatchCase item]
    : expressions
      { $item = new MatchCase(null);
        $item.setExpressionList($expressions.expressionList); }
    ;

isCaseCondition returns [IsCase item]
    : IS_OP 
      { $item = new IsCase($IS_OP); }
      type
      { $item.setType($type.type); }
    ;

satisfiesCaseCondition returns [SatisfiesCase item]
    : SATISFIES 
      { $item = new SatisfiesCase($SATISFIES); }
      qualifiedType
      { $item.setType($qualifiedType.type); }
    ;

forElse returns [ForStatement statement]
    : { $statement=new ForStatement(null); }
      forBlock 
      { $statement.setForClause($forBlock.clause); }
      (
        failBlock
        { $statement.setElseClause($failBlock.clause); }
      )?
    ;

forBlock returns [ForClause clause]
    : FOR_CLAUSE 
      { $clause = new ForClause($FOR_CLAUSE); }
      forIterator 
      { $clause.setForIterator($forIterator.iterator); }
      controlBlock
      { $clause.setBlock($controlBlock.block); }
    ;

failBlock returns [ElseClause clause]
    : ELSE_CLAUSE 
      { $clause = new ElseClause($ELSE_CLAUSE); }
      block
      { $clause.setBlock($block.block); }
    ;

forIterator returns [ForIterator iterator]
    @init { ValueIterator vi = null;
            KeyValueIterator kvi = null; }
    : LPAREN
    { vi = new ValueIterator($LPAREN); 
      kvi = new KeyValueIterator($LPAREN); 
      $iterator = vi; }
    compilerAnnotations
    ( 
      v1=var
      (
        { vi.setVariable($v1.variable); }
        c1=containment
        { vi.setSpecifierExpression($c1.specifierExpression); }
      | 
        { $iterator = kvi; }
        ENTRY_OP
        { kvi.setKeyVariable($v1.variable); }
        v2=var
        { kvi.setValueVariable($v2.variable); }
        c2=containment
        {  kvi.setSpecifierExpression($c2.specifierExpression); }
      )?
    )?
    { if ($iterator!=null)
          $iterator.getCompilerAnnotations().addAll($compilerAnnotations.annotations); }
    RPAREN
    { $iterator.setEndToken($RPAREN); }
    ;
    
containment returns [SpecifierExpression specifierExpression]
    : IN_OP 
      { $specifierExpression = new SpecifierExpression($IN_OP); }
      (expression
      { $specifierExpression.setExpression($expression.expression); })?
    ;
    
whileLoop returns [WhileStatement statement]
    : { $statement = new WhileStatement(null); }
      whileBlock
      { $statement.setWhileClause($whileBlock.clause); }
    ;

whileBlock returns [WhileClause clause]
    : WHILE_CLAUSE
      { $clause = new WhileClause($WHILE_CLAUSE); }
      conditions
      { $clause.setConditionList($conditions.conditionList); }
      controlBlock
      { $clause.setBlock($controlBlock.block); }
    ;

tryCatchFinally returns [TryCatchStatement statement]
    : { $statement = new TryCatchStatement(null); }
      tryBlock 
      { $statement.setTryClause($tryBlock.clause); }
      (
        catchBlock
      { $statement.addCatchClause($catchBlock.clause); }
      )* 
      ( 
        finallyBlock
      { $statement.setFinallyClause($finallyBlock.clause); }
      )?
    ;

tryBlock returns [TryClause clause]
    : TRY_CLAUSE 
      { $clause = new TryClause($TRY_CLAUSE); }
      (
        resource
        { $clause.setResource($resource.resource); }
        controlBlock
        { $clause.setBlock($controlBlock.block); }
      |
        block
        { $clause.setBlock($block.block); }
      )
    ;

catchBlock returns [CatchClause clause]
    : CATCH_CLAUSE 
      { $clause = new CatchClause($CATCH_CLAUSE); }
      catchVariable
      { $clause.setCatchVariable($catchVariable.catchVariable); }
      block
      { $clause.setBlock($block.block); }
    ;

catchVariable returns [CatchVariable catchVariable]
    : LPAREN 
      { $catchVariable=new CatchVariable($LPAREN); }
      (
      variable 
      { $catchVariable.setVariable($variable.variable); }
      )?
      RPAREN 
      { $catchVariable.setEndToken($RPAREN); }
    ;


finallyBlock returns [FinallyClause clause]
    : FINALLY_CLAUSE 
      { $clause = new FinallyClause($FINALLY_CLAUSE); }
      block
      { $clause.setBlock($block.block); }
    ;

resource returns [Resource resource]
    : LPAREN 
    { $resource = new Resource($LPAREN); }
    (
    (COMPILER_ANNOTATION|declarationStart|specificationStart) 
      => specifiedVariable
      { $resource.setVariable($specifiedVariable.variable); }
    | expression
      { $resource.setExpression($expression.expression); }
    )?
    RPAREN
    { $resource.setEndToken($RPAREN); }
    ;

specifiedVariable returns [Variable variable]
    : v=variable 
      { $variable = $v.variable; }
      (
        specifier
        { $variable.setSpecifierExpression($specifier.specifierExpression); }
      )?
    ;

variable returns [Variable variable]
    : compilerAnnotations
      var
      { $variable=$var.variable;
        $variable.getCompilerAnnotations().addAll($compilerAnnotations.annotations); }
    ;
    
var returns [Variable variable]
    : { $variable = new Variable(null); }
    (
      ( type 
        { $variable.setType($type.type); }
      | VOID_MODIFIER
        { $variable.setType(new VoidModifier($VOID_MODIFIER)); }
      | FUNCTION_MODIFIER
        { $variable.setType(new VoidModifier($FUNCTION_MODIFIER)); }
      | VALUE_MODIFIER
        { $variable.setType(new VoidModifier($VALUE_MODIFIER)); }
      )
      mn1=memberName 
      { $variable.setIdentifier($mn1.identifier); }
      ( 
        p1=parameters
        { $variable.addParameterList($p1.parameterList); }
      )*
    | 
      { $variable.setType( new ValueModifier(null) ); }
      mn2=memberName
      { $variable.setIdentifier($mn2.identifier); }
    | 
      { $variable.setType( new FunctionModifier(null) ); }
      mn3=memberName 
      { $variable.setIdentifier($mn3.identifier); }
      (
        p3=parameters
        { $variable.addParameterList($p3.parameterList); }
      )+
    )
    ;

impliedVariable returns [Variable variable]
    : memberName 
      { Variable v = new Variable(null);
        v.setType(new SyntheticVariable(null));
        v.setIdentifier($memberName.identifier);
        SpecifierExpression se = new SpecifierExpression(null);
        Expression e = new Expression(null);
        BaseMemberExpression bme = new BaseMemberExpression(null);
        bme.setIdentifier($memberName.identifier);
        bme.setTypeArguments( new InferredTypeArguments(null) );
        e.setTerm(bme);
        se.setExpression(e);
        v.setSpecifierExpression(se); 
        $variable = v; }
    ;


// Lexer

fragment
Digits
    : Digit ('_' | Digit)*
    ;

fragment
HexDigits
    : HexDigit ('_' | HexDigit)*
    ;

fragment
BinaryDigits
    : BinaryDigit ('_' | BinaryDigit)*
    ;

fragment 
Exponent    
    : ( 'e' | 'E' ) ( '+' | '-' )? Digit*
    ;

fragment
Magnitude
    : 'k' | 'M' | 'G' | 'T' | 'P'
    ;

fragment
FractionalMagnitude
    : 'm' | 'u' | 'n' | 'p' | 'f'
    ;
    
fragment FLOAT_LITERAL :;
//distinguish a float literal from 
//a natural literals followed by a
//member invocation or range op
NATURAL_LITERAL
    : Digits
      ( 
        ('.' ('0'..'9')) => 
        '.' Digits (Exponent|Magnitude|FractionalMagnitude)? { $type = FLOAT_LITERAL; } 
      | FractionalMagnitude { $type = FLOAT_LITERAL; }
      | Magnitude?
      )
    | '#' HexDigits
    | '$' BinaryDigits
    ;
    
fragment ASTRING_LITERAL:;
fragment AVERBATIM_STRING:;

CHAR_LITERAL
    :   '\'' CharPart '\''
    ;

fragment STRING_START:;
STRING_LITERAL
    :   '"' StringPart ( '"' | '``' { $type = STRING_START; } (('`' ~'`') => '`')? )
    ;

fragment STRING_MID:;
STRING_END
    :   '``' StringPart ( '"' | '``' { $type = STRING_MID; } (('`' ~'`') => '`')? )
    ;

VERBATIM_STRING
    :	'"""' (~'"'|'"' ~'"'| '""' ~'"')* '"""' ('"' '"'?)?
    ;

/*
 Stef: we must take 32-bit code points into account here because AntLR considers each
 character to be 16-bit like in Java, which means that it will consider a high/low surrogate
 pair as two characters and refuse it in a character literal. So we match either a code point
 pair, or a normal 16-bit code point.
*/
fragment
CharPart
    : ( ~('\\' | '\'') | EscapeSequence )*
    ;
    
/*
 Stef: AntLR considers each character to be 16-bit like in Java, which means that it will consider a 
 high/low surrogate pair as two characters, BUT because the special characters we care about, such
 as termination quotes or backslash escapes (including unicode escapes) all fall outside the range
 of both the high and low surrogate parts of 32-bit code points character pairs, so we don't care
 because 32-bit code points, even taken as two chars, cannot match any of our special characters,
 so we can just process them as-is.
*/
fragment
StringPart
    : ( ~('\\' | '"' | '`') | ( ('`' ~'`') => '`' ) | EscapeSequence )*
    ;
    
fragment
EscapeSequence 
    :   '\\' 
        ( ~'{' | '{' (~'}')* '}' )
    ;

WS  
    :   (
             ' '
        |    '\r'
        |    '\t'
        |    '\f'
        |    '\n'
        )+
        {
            //skip();
            $channel = HIDDEN;
        }          
    ;

LINE_COMMENT
    :   ('//'|'#!') ~('\n'|'\r')*  ('\r\n' | '\r' | '\n')?
        {
            $channel = HIDDEN;
        }
    ;   

MULTI_COMMENT
    :   '/*'
        (    ~('/'|'*')
        |    ('/' ~'*') => '/'
        |    ('*' ~'/') => '*'
        |    MULTI_COMMENT
        )*
        '*/'?
        //('*/'/|{displayRecognitionError(getTokenNames(), new MismatchedSetException(null,input));})
        {
            $channel = HIDDEN;
        }
        ;

ASSERT
    : 'assert'
    ;

ABSTRACTED_TYPE
    :   'abstracts'
    ;

ADAPTED_TYPES
    :   'adapts'
    ;

ASSIGN
    :   'assign'
    ;
    
ALIAS
    :   'alias'
    ;

BREAK
    :   'break'
    ;

CASE_CLAUSE
    :   'case'
    ;

CATCH_CLAUSE
    :   'catch'
    ;

CLASS_DEFINITION
    :   'class'
    ;

CONTINUE
    :   'continue'
    ;
    
DYNAMIC
    :   'dynamic'
    ;
    
ELSE_CLAUSE
    :   'else'
    ;            

EXISTS
    :   'exists'
    ;

EXTENDS
    :   'extends'
    ;

FINALLY_CLAUSE
    :   'finally'
    ;

FOR_CLAUSE
    :   'for'
    ;

TYPE_CONSTRAINT
    :   'given'
    ;

IF_CLAUSE
    :   'if'
    ;

SATISFIES
    :   'satisfies'
    ;

IMPORT
    :   'import'
    ;

INTERFACE_DEFINITION
    :   'interface'
    ;

VALUE_MODIFIER
    :   'value'
    ;

FUNCTION_MODIFIER
    :   'function'
    ;

MODULE
    :   'module'
    ;

PACKAGE
    :   'package'
    ;

NONEMPTY
    :   'nonempty'
    ;

RETURN
    :   'return'
    ;

SUPER
    :   'super'
    ;

SWITCH_CLAUSE
    :   'switch'
    ;

THEN_CLAUSE
    :   'then'
    ;            

THIS
    :   'this'
    ;

OUTER
    :   'outer'
    ;

OBJECT_DEFINITION
    :   'object'
    ;

CASE_TYPES
    :   'of'
    ;

OUT
    :   'out'
    ;

THROW
    :   'throw'
    ;

TRY_CLAUSE
    :   'try'
    ;

VOID_MODIFIER
    :   'void'
    ;

WHILE_CLAUSE
    :   'while'
    ;

ELLIPSIS
    :   '...'
    ;

RANGE_OP
    :   '..'
    ;

SEGMENT_OP
    :   ':'
    ;

MEMBER_OP
    :   '.' ;

LPAREN
    :   '('
    ;

RPAREN
    :   ')'
    ;

LBRACE
    :   '{'
    ;

RBRACE
    :   '}'
    ;

LBRACKET
    :   '['
    ;

RBRACKET
    :   ']'
    ;

SEMICOLON
    :   ';'
    ;

COMMA
    :   ','
    ;
    
SPECIFY
    :   '='
    ;

COMPUTE
    :   '=>'
    ;

SAFE_MEMBER_OP
    :   '?.'
    ;

OPTIONAL
    :    '?'
    ;

NOT_OP
    :   '!'
    ;

COMPLEMENT_OP
    :   '~'
    ;

EQUAL_OP
    :   '=='
    ;

IDENTICAL_OP
    :   '==='
    ;

AND_OP
    :   '&&'
    ;

OR_OP
    :   '||'
    ;

INCREMENT_OP
    :   '++'
    ;

DECREMENT_OP
    :   '--'
    ;

SUM_OP
    :   '+'
    ;

DIFFERENCE_OP
    :   '-'
    ;

SPREAD_OP
    :    '*.'
    ;

PRODUCT_OP
    :   '*'
    ;

QUOTIENT_OP
    :   '/'
    ;

INTERSECTION_OP
    :   '&'
    ;

UNION_OP
    :   '|'
    ;

REMAINDER_OP
    :   '%'
    ;

NOT_EQUAL_OP
    :   '!='
    ;

LARGER_OP
    :   '>'
    ;

SMALLER_OP
    :   '<'
    ;        

LARGE_AS_OP
    :   '>='
    ;

SMALL_AS_OP
    :   '<='
    ;        

ENTRY_OP
    :   '->'
    ;
    
COMPARE_OP
    :   '<=>'
    ;
    
IN_OP
    :   'in'
    ;

IS_OP
    :   'is'
    ;

POWER_OP
    :    '^'
    ;

ADD_SPECIFY
    :   '+='
    ;

SUBTRACT_SPECIFY
    :   '-='
    ;

MULTIPLY_SPECIFY
    :   '*='
    ;

DIVIDE_SPECIFY
    :   '/='
    ;

INTERSECT_SPECIFY
    :   '&='
    ;

UNION_SPECIFY
    :   '|='
    ;

COMPLEMENT_SPECIFY
    :   '~='
    ;
    
REMAINDER_SPECIFY
    :   '%='
    ;

AND_SPECIFY
    :   '&&='
    ;

OR_SPECIFY
    :   '||='
    ;

SUPER_OP
    :   '::'
    ;

COMPILER_ANNOTATION
    :   '@'
    ;

fragment
LIDENTIFIER :;
fragment
PIDENTIFIER :;
fragment
AIDENTIFIER :;

UIDENTIFIER 
    :   IdentifierStart IdentifierPart*
        { int cp = $text.codePointAt(0);
          if (cp=='_' || Character.isLowerCase(cp)) $type=LIDENTIFIER; }
    |   UIdentifierPrefix name=IdentifierPart+
        { setText($text.substring(2)); }
    |   LIdentifierPrefix name=IdentifierPart+
        { setText($text.substring(2)); $type=LIDENTIFIER; }
    ;

fragment
IdentifierStart
    :   '_'
    |   Letter
        { if (!Character.isJavaIdentifierStart($text.codePointAt(0))) { 
          //TODO: error!
        } }
    ;       

fragment
LIdentifierPrefix
    : '\\i'
    ;

fragment
UIdentifierPrefix
    : '\\I'
    ;
    
fragment 
IdentifierPart
    :   '_'
    |   Digit
    |   Letter
        { if (!Character.isJavaIdentifierPart($text.codePointAt(0))) { 
          //TODO: error!
        } }
    ;

fragment
Letter
    : 'a'..'z' 
    | 'A'..'Z' 
    | '\u00c0'..'\ufffe'
    ;

fragment
Digit
    : '0'..'9'
    ;

fragment
HexDigit
    : '0'..'9' | 'A'..'F' | 'a'..'f'
    ;

fragment
BinaryDigit
    : '0'|'1'
    ;
