unit ucore;

interface

uses
  Windows, Messages, Variants, Graphics, Controls, FileCtrl,
  Dialogs, StdCtrls,  Classes, SysUtils, Forms, ExtCtrls,
  DB, ZConnection, ZAbstractRODataset, ZAbstractDataset, ZDataset, ZSqlProcessor,
  ADODb, DBTables, Printers, QRPrntr,
  udatatypes_apps,
  // Classes
  ClassParametrosDeEntrada,
  ClassArquivoIni, ClassStrings, ClassConexoes, ClassConf, ClassMySqlBases,
  ClassTextFile, ClassDirectory, ClassLog, ClassFuncoesWin, ClassLayoutArquivo,
  ClassBlocaInteligente, ClassFuncoesBancarias, ClassPlanoDeTriagem, ClassExpressaoRegular,
  ClassStatusProcessamento, ClassDateTime, ClassSMTPDelphi;

type

  TCore = class(TObject)
  private

    __queryMySQL_processamento__    : TZQuery;
    __queryMySQL_plano_de_triagem__ : TZQuery;

    // FUNÇÃO DE PROCESSAMENTO
      Procedure PROCESSAMENTO();
      function getNumeroLotePedido(): String;
      function GravaNumeroLotePedido(NumeroLotePedido: String): Boolean;

      procedure StoredProcedure_Dropar(Nome: string; logBD:boolean=false; idprograma:integer=0);

      function StoredProcedure_Criar(Nome : string; scriptSQL: TStringList): boolean;

      procedure StoredProcedure_Executar(Nome: string; ComParametro:boolean=false; logBD:boolean=false; idprograma:integer=0);

  public

    __ListaPlanoDeTriagem__       : TRecordPlanoTriagemCorreios;

    objParametrosDeEntrada   : TParametrosDeEntrada;
    objConexao               : TMysqlDatabase;
    objPlanoDeTriagem        : TPlanoDeTriagem;
    objString                : TFormataString;
    objLogar                 : TArquivoDelog;
    objDateTime              : TFormataDateTime;
    objArquivoIni            : TArquivoIni;
    objArquivoDeConexoes     : TArquivoDeConexoes;
    objArquivoDeConfiguracao : TArquivoConf;
    objDiretorio             : TDiretorio;
    objFuncoesWin            : TFuncoesWin;
    objLayoutArquivoCliente  : TLayoutCliente;
    objBlocagemInteligente   : TBlocaInteligente;
    objFuncoesBancarias      : TFuncoesBancarias;
    objExpressaoRegular      : TExpressaoRegular;
    objStatusProcessamento   : TStausProcessamento;
    objEmail                 : TSMTPDelphi;

    function Compactar_Arquivo_7z(Arquivo, destino : String; mover_arquivo: Boolean=false; ZIP: Boolean=false): integer;
    PROCEDURE COMPACTAR_ARQUIVO(ARQUIVO_ORIGEM, PATH_DESTINO: String; MOVER_ARQUIVO: Boolean=FALSE; ZIP: Boolean=false);

    function Extrair_Arquivo_7z(Arquivo, destino : String): integer;
    PROCEDURE EXTRAIR_ARQUIVO(ARQUIVO_ORIGEM, PATH_DESTINO: String);

    function PesquisarLote(LOTE_PEDIDO : STRING; status : Integer): Boolean;

    procedure ExcluirBase(NomeTabela: String);
    procedure ExcluirTabela(NomeTabela: String);
    function EnviarEmail(Assunto: string=''; Corpo: string=''): Boolean;
    procedure MainLoop();
    constructor create();

  end;

implementation

uses uMain;

constructor TCore.create();
var
  sMSG                       : string;
  sArquivosScriptSQL         : string;
  stlScripSQL                : TStringList;
begin

  try

    stlScripSQL                          := TStringList.Create();

    objStatusProcessamento               := TStausProcessamento.create();
    objParametrosDeEntrada               := TParametrosDeEntrada.Create();

    objLogar                             := TArquivoDelog.Create();
    if FileExists(objLogar.getArquivoDeLog()) then
      objFuncoesWin.DelFile(objLogar.getArquivoDeLog());

    objFuncoesWin                        := TFuncoesWin.create(objLogar);
    objString                            := TFormataString.Create(objLogar);
    objDateTime                          := TFormataDateTime.Create(objLogar);
    objLayoutArquivoCliente              := TLayoutCliente.Create();
    objFuncoesBancarias                  := TFuncoesBancarias.Create();
    objExpressaoRegular                  := TExpressaoRegular.Create();

    objArquivoIni                        := TArquivoIni.create(objLogar,
                                                               objString,
                                                               ExtractFilePath(Application.ExeName),
                                                               ExtractFileName(Application.ExeName));

    objArquivoDeConexoes                 := TArquivoDeConexoes.create(objLogar,
                                                                      objString,
                                                                      objArquivoIni.getPathConexoes());

    objArquivoDeConfiguracao             := TArquivoConf.create(objArquivoIni.getPathConfiguracoes(),
                                                                ExtractFileName(Application.ExeName));

    objParametrosDeEntrada.ID_PROCESSAMENTO := objArquivoDeConfiguracao.getIDProcessamento;

    objConexao                           := TMysqlDatabase.Create();

    if objArquivoIni.getPathConfiguracoes() <> '' then
    begin

      objParametrosDeEntrada.PATHENTRADA                                := objArquivoDeConfiguracao.getConfiguracao('path_default_arquivos_entrada');
      objParametrosDeEntrada.PATHSAIDA                                  := objArquivoDeConfiguracao.getConfiguracao('path_default_arquivos_saida');
      objParametrosDeEntrada.TABELA_PROCESSAMENTO                       := objArquivoDeConfiguracao.getConfiguracao('tabela_processamento');
      objParametrosDeEntrada.TABELA_LOTES_PEDIDOS                       := objArquivoDeConfiguracao.getConfiguracao('TABELA_LOTES_PEDIDOS');
      objParametrosDeEntrada.TABELA_PLANO_DE_TRIAGEM                    := objArquivoDeConfiguracao.getConfiguracao('tabela_plano_de_triagem');
      objParametrosDeEntrada.CARREGAR_PLANO_DE_TRIAGEM_MEMORIA          := objArquivoDeConfiguracao.getConfiguracao('CARREGAR_PLANO_DE_TRIAGEM_MEMORIA');
      objParametrosDeEntrada.TABELA_BLOCAGEM_INTELIGENTE                := objArquivoDeConfiguracao.getConfiguracao('TABELA_BLOCAGEM_INTELIGENTE');
      objParametrosDeEntrada.TABELA_BLOCAGEM_INTELIGENTE_RELATORIO      := objArquivoDeConfiguracao.getConfiguracao('TABELA_BLOCAGEM_INTELIGENTE_RELATORIO');
      objParametrosDeEntrada.TABELA_ENTRADA_SP                          := objArquivoDeConfiguracao.getConfiguracao('TABELA_ENTRADA_SP');
      objParametrosDeEntrada.TABELA_AUX_SP                              := objArquivoDeConfiguracao.getConfiguracao('TABELA_AUX_SP');
      objParametrosDeEntrada.LIMITE_DE_SELECT_POR_INTERACOES_NA_MEMORIA := objArquivoDeConfiguracao.getConfiguracao('numero_de_select_por_interacoes_na_memoria');
      objParametrosDeEntrada.NUMERO_DE_IMAGENS_PARA_BLOCAGENS           := objArquivoDeConfiguracao.getConfiguracao('NUMERO_DE_IMAGENS_PARA_BLOCAGENS');
      objParametrosDeEntrada.BLOCAR_ARQUIVO                             := objArquivoDeConfiguracao.getConfiguracao('BLOCAR_ARQUIVO');
      objParametrosDeEntrada.BLOCAGEM                                   := objArquivoDeConfiguracao.getConfiguracao('BLOCAGEM');
      objParametrosDeEntrada.MANTER_ARQUIVO_ORIGINAL                    := objArquivoDeConfiguracao.getConfiguracao('MANTER_ARQUIVO_ORIGINAL');
      objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO                     := objArquivoDeConfiguracao.getConfiguracao('FORMATACAO_LOTE_PEDIDO');
      objParametrosDeEntrada.lista_de_caracteres_invalidos              := objArquivoDeConfiguracao.getConfiguracao('lista_de_caracteres_invalidos');
      objParametrosDeEntrada.eHost                                      := objArquivoDeConfiguracao.getConfiguracao('eHost');
      objParametrosDeEntrada.eUser                                      := objArquivoDeConfiguracao.getConfiguracao('eUser');
      objParametrosDeEntrada.eFrom                                      := objArquivoDeConfiguracao.getConfiguracao('eFrom');
      objParametrosDeEntrada.eTo                                        := objArquivoDeConfiguracao.getConfiguracao('eTo');

      objParametrosDeEntrada.IMAGEM_UNICA                               := objArquivoDeConfiguracao.getConfiguracao('IMAGEM_UNICA');
      objParametrosDeEntrada.IMAGEM_PG1                                 := objArquivoDeConfiguracao.getConfiguracao('IMAGEM_PG1');
      objParametrosDeEntrada.IMAGEM_PGN                                 := objArquivoDeConfiguracao.getConfiguracao('IMAGEM_PGN');

      objParametrosDeEntrada.IMAGEM_UNICA_FAC_REGISTRADO                := objArquivoDeConfiguracao.getConfiguracao('IMAGEM_UNICA_FAC_REGISTRADO');
      objParametrosDeEntrada.IMAGEM_PG1_FAC_REGISTRADO                  := objArquivoDeConfiguracao.getConfiguracao('IMAGEM_PG1_FAC_REGISTRADO');
      objParametrosDeEntrada.IMAGEM_PGN_FAC_REGISTRADO                  := objArquivoDeConfiguracao.getConfiguracao('IMAGEM_PGN_FAC_REGISTRADO');

      objParametrosDeEntrada.IMAGEM                                     := objArquivoDeConfiguracao.getConfiguracao('IMAGEM');
      objParametrosDeEntrada.IMAGEM_PG2                                 := objArquivoDeConfiguracao.getConfiguracao('IMAGEM_PG2');
      objParametrosDeEntrada.EXTENCAO_ARQUIVO                           := objArquivoDeConfiguracao.getConfiguracao('EXTENCAO_ARQUIVO');
      objParametrosDeEntrada.NUMERO_DE_IMPRESSOES                       := objArquivoDeConfiguracao.getConfiguracao('NUMERO_DE_IMPRESSOES');

      objParametrosDeEntrada.app_7z_32bits                              := objArquivoDeConfiguracao.getConfiguracao('app_7z_32bits');
      objParametrosDeEntrada.app_7z_64bits                              := objArquivoDeConfiguracao.getConfiguracao('app_7z_64bits');
      objParametrosDeEntrada.ARQUITETURA_WINDOWS                        := objArquivoDeConfiguracao.getConfiguracao('ARQUITETURA_WINDOWS');

      objParametrosDeEntrada.CODIGO_ADM_CONTRATO                        := objArquivoDeConfiguracao.getConfiguracao('CODIGO_ADM_CONTRATO');
      objParametrosDeEntrada.DR_POSTAGEM                                := objArquivoDeConfiguracao.getConfiguracao('DR_POSTAGEM');

      objParametrosDeEntrada.ENVIAR_EMAIL                               := objArquivoDeConfiguracao.getConfiguracao('ENVIAR_EMAIL');



      objLogar.Logar('[DEBUG] TfrmMain.FormCreate() - Versão do programa: ' + objFuncoesWin.GetVersaoDaAplicacao());

      objParametrosDeEntrada.PathArquivo_TMP := objArquivoIni.getPathArquivosTemporarios();

      // Criando a Conexao
      objConexao.ConectarAoBanco(objArquivoDeConexoes.getHostName,
                                 'mysql',
                                 objArquivoDeConexoes.getUser,
                                 objArquivoDeConexoes.getPassword,
                                 objArquivoDeConexoes.getProtocolo
                                 );

      sArquivosScriptSQL := ExtractFileName(Application.ExeName);
      sArquivosScriptSQL := StringReplace(sArquivosScriptSQL, '.exe', '.sql', [rfReplaceAll, rfIgnoreCase]);

      stlScripSQL.LoadFromFile(objArquivoIni.getPathScripSQL() + sArquivosScriptSQL);
      objConexao.ExecutaScript(stlScripSQL);

      objBlocagemInteligente   := TBlocaInteligente.create(objParametrosDeEntrada,
                                                           objConexao,
                                                           objFuncoesWin,
                                                           objString,
                                                           objLogar);

      // Criando Objeto de Plano de Triagem
      if StrToBool(objParametrosDeEntrada.CARREGAR_PLANO_DE_TRIAGEM_MEMORIA) then
        objPlanoDeTriagem := TPlanoDeTriagem.create(objConexao,
                                                    objLogar,
                                                    objString,
                                                    objParametrosDeEntrada.TABELA_PLANO_DE_TRIAGEM, fac);

      objParametrosDeEntrada.PEDIDO_LOTE      := getNumeroLotePedido();

      objParametrosDeEntrada.stlRelatorioQTDE := TStringList.Create();

    end;

  except
    on E:Exception do
    begin

      sMSG := '[ERRO] Não foi possível inicializar as configurações aq do programa. '+#13#10#13#10
            + ' EXCEÇÃO: '+E.Message+#13#10#13#10
            + ' O programa será encerrado agora.';

      showmessage(sMSG);

      objLogar.Logar(sMSG);

      Application.Terminate;
    end;
  end;

end;

function TCore.getNumeroLotePedido(): String;
var
  sComando : string;
  iPedido  : Integer;
begin
  sComando := ' SELECT max(LOTE_PEDIDO) as LOTE_PEDIDO FROM  ' + objParametrosDeEntrada.TABELA_LOTES_PEDIDOS;
  objStatusProcessamento := objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

  iPedido := StrToIntDef(__queryMySQL_processamento__.FieldByName('LOTE_PEDIDO').AsString, 0) + 1;
  Result := FormatFloat(objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO, iPedido);
end;

function TCore.GravaNumeroLotePedido(NumeroLotePedido: String): Boolean;
var
  sComando : string;
  sData    : string;
begin

  sData := FormatDateTime('YYYY-MM-DD hh:mm:ss', Now());

  sComando := ' insert into ' + objParametrosDeEntrada.TABELA_LOTES_PEDIDOS + '(LOTE_PEDIDO, VALIDO, DATA_CRIACAO, RELATORIO_QTD)'
            + ' Value(' + NumeroLotePedido + ',"S", "' + sData + '","' + objParametrosDeEntrada.stlRelatorioQTDE.Text + '")';
  Result := objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 1).status;
end;


procedure TCore.MainLoop();
var
  sMSG : string;
begin

  objLogar.Logar('[DEBUG] TCore.MainLoop() - begin...');
  try
    try

      if objParametrosDeEntrada.PathEntrada = '' then
        objParametrosDeEntrada.PathEntrada := '.\';

      if objParametrosDeEntrada.PathSaida = '' then
        objParametrosDeEntrada.PathSaida := '.\';

      objDiretorio := TDiretorio.create(objParametrosDeEntrada.PathEntrada);
      objParametrosDeEntrada.PathEntrada := objDiretorio.getDiretorio();

      //objDiretorio.setDiretorio(objParametrosDeEntrada.PathSaida);
      //objParametrosDeEntrada.PathSaida   := objDiretorio.getDiretorio();

      //if not DirectoryExists(objParametrosDeEntrada.PathSaida) then
      //  ForceDirectories(objParametrosDeEntrada.PathSaida);

      PROCESSAMENTO();

    finally

      if Assigned(objDiretorio) then
      begin
        objDiretorio.destroy;
        Pointer(objDiretorio) := nil;
      end;

      if not objStatusProcessamento.status then
        ShowMessage('ERROS OCORRERAM !!!' + #13 + objStatusProcessamento.msg)
      else
      begin
        if StrToInt(objParametrosDeEntrada.PEDIDO_LOTE_MANUAL) = 0 then
          GravaNumeroLotePedido(objParametrosDeEntrada.PEDIDO_LOTE);
        objParametrosDeEntrada.PEDIDO_LOTE := getNumeroLotePedido();
      end;

    end;

  except

    // 0------------------------------------------0
    // |  Excessões desntro do objCore caem aqui  |
    // 0------------------------------------------0
    on E:Exception do
    begin

      sMSG :='Erro ao execultar a Função MainLoop(). ' + #13#10#13#10
                 +'EXCEÇÃO: '+E.Message+#13#10#13#10
                 +'O programa será encerrado agora.';

      IF StrToBool(objParametrosDeEntrada.ENVIAR_EMAIL) THEN
        EnviarEmail('ERRO DE PROCESSAMENTO !!!', sMSG + #13 + #13 + 'SEGUE LOG EM ANEXO.');

      showmessage(sMSG);
      objLogar.Logar(sMSG);

    end;
  end;

  objLogar.Logar('[DEBUG] TCore.MainLoop() - ...end');

end;

Procedure TCore.PROCESSAMENTO();
Var
//
// Variáveis básicas
flArquivoEntrada    : TextFile;
objString           : TFormataString;
sPathEntrada        : string;
sPathEntradaTMP     : string;
sPathSaida          : string;
sArquivoSaida       : string;
sLinha              : string;
sValues             : string;
sArquivoEntrada     : string;
sArquivoEntradaZIP  : string;
sArquivoEntradaCIF  : string;
sComando            : string;
sNumeroDeCartao     : string;
sCampos             : string;

sCodigoCategoria    : string;

ListaDeArquivosCIF  : TStringList;

iContArquivos       : Integer;
iTotalDeArquivos    : Integer;

iContArquivosCIF       : Integer;
iTotalDeArquivosCIF    : Integer;

iContImpressoes     : Integer;


// Variáveis de controle do select
iTotalDeRegistrosDaTabela   : Integer;
iLimit                      : Integer;
iTotalDeInteracoesDeSelects : Integer;
iResto                      : Integer;
iRegInicial                 : Integer;
iQtdeRegistros              : Integer;
iContInteracoesDeSelects    : Integer;

// Demias Variáveis
sTipoDeRegistro : string;
sListaDeLotes   : string;

sQuantidade                  : string;
sPeso                        : String;

i82015QuantidadeTotal        : Integer;
i82023QuantidadeTotal        : Integer;
i82031QuantidadeTotal        : Integer;

d82015PesoTotal              : Double;
d82023PesoTotal              : Double;
d82031PesoTotal              : Double;


iContLinhas                  : Integer;
iContLinhasNaPagina          : Integer;

iContLinhaPorPagina          : Integer;
iContPagina                  : Integer;
iTotalDePaginas              : Integer;

stlLOCAL_PesoUnitario        : TStringList;
stlLOCAL_Quantidades         : TStringList;
stlLOCAL_Totais              : TStringList;
iContLinhasLOCAL             : Integer;

stlESTADUAL_PesoUnitario        : TStringList;
stlESTADUAL_Quantidades         : TStringList;
stlESTADUAL_Totais              : TStringList;
iContLinhasESTADUAL             : Integer;

stlNACIONAL_PesoUnitario        : TStringList;
stlNACIONAL_Quantidades         : TStringList;
stlNACIONAL_Totais              : TStringList;
iContLinhasNACIONAL             : Integer;

iTotalDeLinhasLista          : Integer;


stlListaDeLotes              : TStringList;
stlCategorias                : TStringList;
stlListaDePesos              : TStringList;
stlListaDeNCartao            : TStringList;


rrLayoutArquivo              : RLayoutModelo;

//Imagem : TBitMap;
Lista             : TQRprinter;

iContCategoria         : Integer;
iContPesoUnitario      : Integer;
iContLotes             : Integer;
iContNumeroContratos   : Integer;
iNumeroDeLotesNaPagina : Integer;
iLimiteDeLotesNaPagina : Integer;
iAjusteLinha           : Integer;
iLimiteLotes           : Integer;
iLimiteColunas         : Integer;
xDesloc                : Integer;
xDesloc2               : Integer;
yDesloc                : Integer;
yDeslocPg2             : Integer;
iContLinhasExtrasOG2   : Integer;
iDeslocYLinhaExtra     : Integer;
iNumeroCampos          : Integer;

iLimiteDeLinhasPorPaginas : Integer;

img                    :TImage;
img_PG2                :TImage;

bFacRegistrado                             : Boolean;
TIPO_FAC                                   : string;
CODIGO_SERVICO_LOCAL                       : string;
CODIGO_SERVICO_ESTADUAL                    : string;
CODIGO_SERVICO_NACIONAL                    : string;
sPRIMEIRO_OBJ                              : string;
sULTIMO_OBJ                                : string;

IMG_FOLHA_UNICA                            : string;
IMG_FOLHA_01                               : string;
IMG_FOLHA_0N                               : string;

LOCAL                                      : string;
sFlagAR                                    : string;

//
objArquivoSaida : TArquivoTexto;

Arq_Arquivo_Entada : TextFile;

sOperadora : string;
sContrato : string;
sCep : string;

Image : TBitmap;

begin

  //criarPlanoDeTriagem(ParametrosDeEntrada.TABELA_PLANO_DE_TRIAGEM);

  stlListaDeLotes      := TStringList.Create();
  stlCategorias        := TStringList.Create();
  stlListaDePesos      := TStringList.Create();
  stlListaDeNCartao    := TStringList.Create();

  //==============================================================================================
  //                         Alimentando nome dos campos da tabela de Cliente
  //==============================================================================================
  sComando := 'describe ' + objParametrosDeEntrada.tabela_processamento;
  objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

  while not __queryMySQL_processamento__.Eof do
  Begin
    sCampos := sCampos + __queryMySQL_processamento__.FieldByName('Field').AsString;
    __queryMySQL_processamento__.Next;
    if not __queryMySQL_processamento__.Eof then
      sCampos := sCampos + ',';
  end;

  sComando := 'delete from ' + objParametrosDeEntrada.tabela_processamento;
  objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 1);

  //==============================================================================================
  //                               CARREGA CIF NA TABELA
  //==============================================================================================
  iTotalDeArquivos := objParametrosDeEntrada.ListaDeArquivosDeEntrada.Count;

  ListaDeArquivosCIF  := TStringList.Create();

  sPathEntrada    := objString.AjustaPath(objParametrosDeEntrada.PATHENTRADA);
  sPathEntradaTMP := sPathEntrada + 'TMP' + PathDelim;

  for iContArquivos := 0 to iTotalDeArquivos - 1 do
  begin

//  ForceDirectories(sPathEntradaTMP);

    sArquivoEntradaZIP := objParametrosDeEntrada.ListaDeArquivosDeEntrada.Strings[iContArquivos];

//    EXTRAIR_ARQUIVO(sPathEntrada + sArquivoEntradaZIP, sPathEntrada);

//    EXTRAIR_ARQUIVO(sPathEntrada + sArquivoEntradaZIP, sPathEntradaTMP);

//    ListaDeArquivosCIF.Clear;
//    objFuncoesWin.ObterListaDeArquivosDeUmDiretorioV2(sPathEntradaTMP, ListaDeArquivosCIF, '*.*');

//    iTotalDeArquivosCIF := ListaDeArquivosCIF.Count;

//    for iContArquivosCIF := 0 to iTotalDeArquivosCIF -1 do
//    begin

//      sArquivoEntradaCIF := ListaDeArquivosCIF.Strings[iContArquivosCIF];

      sArquivoEntradaCIF := StringReplace(sArquivoEntradaZIP, '.ZIP', '.TXT', [rfReplaceAll, rfIgnoreCase]);

      AssignFile(flArquivoEntrada, sPathEntrada + sArquivoEntradaCIF);
      Reset(flArquivoEntrada);


      while not Eof(flArquivoEntrada) do
      Begin

        Readln(flArquivoEntrada, sLinha);

        iNumeroCampos := objString.GetNumeroOcorrenciasCaracter(sLinha, '|');

        if iNumeroCampos > 0 then
        begin

          if iNumeroCampos = 8 then
          begin

            objParametrosDeEntrada.N_CONTRATO             := objString.getTermo(1, '|', sLinha);
            objParametrosDeEntrada.CARTAO                 := objString.getTermo(2, '|', sLinha);
            objParametrosDeEntrada.LOTE                   := objString.getTermo(3, '|', sLinha);
            objParametrosDeEntrada.COD_UN_POST            := objString.getTermo(4, '|', sLinha);
            objParametrosDeEntrada.CEP_UNI_POST           := objString.getTermo(5, '|', sLinha);

          end;

          if iNumeroCampos = 13 then
          begin

            objParametrosDeEntrada.SEQUENCIA_OBJ       := objString.getTermo(1, '|', sLinha);
            objParametrosDeEntrada.PESO_UNITARIO       := objString.getTermo(2, '|', sLinha);
            objParametrosDeEntrada.COD_CATEGORIA       := objString.getTermo(3, '|', sLinha);

            sCodigoCategoria                           := objParametrosDeEntrada.COD_CATEGORIA;

            //========================================================
            //  FALG PARA IDENTIFICAR SE É AR
            //========================================================
            if (sCodigoCategoria = '82015')  //       FAC LOCAL SIMPLES
             or(sCodigoCategoria = '82104')  //       FAC LOCAL REGISTRADO
             or(sCodigoCategoria = '82139')  //       FAC LOCAL REGISTRADO COM AR
             or(sCodigoCategoria = '84107')  // GPOST FAC LOCAL SIMPLES
             or(sCodigoCategoria = '84077')  // GPOST FAC LOCAL REGISTRADO
             or(sCodigoCategoria = '84034')  // GPOST FAC LOCAL REGISTRADO COM AR
            then
              LOCAL:='1'
            ELSE
            if (sCodigoCategoria = '82023') //       FAC ESTADUAL SIMPLES
             or(sCodigoCategoria = '82112') //       FAC ESTADUAL REGISTRADO
             or(sCodigoCategoria = '82147') //       FAC ESTADUAL REGISTRADOCOM AR
             or(sCodigoCategoria = '84093') // GPOST FAC ESTADUAL SIMPLES
             or(sCodigoCategoria = '84069') // GPOST FAC ESTADUAL REGISTRADO
             or(sCodigoCategoria = '84026') // GPOST FAC ESTADUAL REGISTRADO COM AR
            then
              LOCAL:='2'
            ELSE
            if (sCodigoCategoria = '82031') //       FAC NACIONAL SIMPLES
             or(sCodigoCategoria = '82120') //       FAC NACIONALREGISTRADO
             or(sCodigoCategoria = '82155') //       FAC NACIONAL REGISTRADO COM AR
             or(sCodigoCategoria = '84085') // GPOST FAC NACIONAL SIMPLES
             or(sCodigoCategoria = '84050') // GPOST FAC NACIONAL REGISTRADO
             or(sCodigoCategoria = '84018') // GPOST FAC NACIONAL REGISTRADO COM AR
            then
              LOCAL:='3'
            ELSE
              LOCAL:='1';

            sValues := '"' + objParametrosDeEntrada.COD_CATEGORIA + '",'
                     +  Copy(objParametrosDeEntrada.PESO_UNITARIO, 1, 4) + '.' + Copy(objParametrosDeEntrada.PESO_UNITARIO, 5, 2) + ','
                     + '"' + objParametrosDeEntrada.DR_POSTAGEM         + '",'
                     + '"' + objParametrosDeEntrada.CODIGO_ADM_CONTRATO + '",'
                     + '"' + objParametrosDeEntrada.CARTAO              + '",'
                     + '"' + objParametrosDeEntrada.LOTE                + '",'
                     + '"' + objParametrosDeEntrada.COD_UN_POST         + '",'
                     + '"' + objParametrosDeEntrada.CEP_UNI_POST        + '",'
                     + '"' + objParametrosDeEntrada.N_CONTRATO          + '",'
                     + '"' + objParametrosDeEntrada.SEQUENCIA_OBJ       + '"';

            sComando := 'Insert into ' + objParametrosDeEntrada.tabela_processamento + ' (' + sCampos + ') values(' + sValues + ')';
            objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 1);

          end;




        end
        else
        Begin

          sTipoDeRegistro := copy(sLinha, 1, 1);

          if sTipoDeRegistro = '1' then
          begin
            objParametrosDeEntrada.COD_DR              := copy(sLinha, 2,2);
            objParametrosDeEntrada.CODIGO_ADM_CONTRATO := copy(sLinha, 4,8);
            objParametrosDeEntrada.CARTAO              := copy(sLinha, 12,12);
            objParametrosDeEntrada.LOTE                := copy(sLinha, 24,5);
            objParametrosDeEntrada.COD_UN_POST         := copy(sLinha, 29,8);
            objParametrosDeEntrada.CEP_UNI_POST        := copy(sLinha, 37,8);
            objParametrosDeEntrada.N_CONTRATO          := copy(sLinha, 45,10);
          end;

          if sTipoDeRegistro = '2' then
          begin
            objParametrosDeEntrada.SEQUENCIA_OBJ       := copy(sLinha, 2,11);
            objParametrosDeEntrada.PESO_UNITARIO       := copy(sLinha, 13,6);
            objParametrosDeEntrada.COD_CATEGORIA       := copy(sLinha, 27,5);

            sValues := '"' + objParametrosDeEntrada.COD_CATEGORIA + '",'
                     +       Copy(objParametrosDeEntrada.PESO_UNITARIO, 1, 4) + '.' + Copy(objParametrosDeEntrada.PESO_UNITARIO, 5, 2) + ','
                     + '"' + objParametrosDeEntrada.COD_DR              + '",'
                     + '"' + objParametrosDeEntrada.CODIGO_ADM_CONTRATO + '",'
                     + '"' + objParametrosDeEntrada.CARTAO              + '",'
                     + '"' + objParametrosDeEntrada.LOTE                + '",'
                     + '"' + objParametrosDeEntrada.COD_UN_POST         + '",'
                     + '"' + objParametrosDeEntrada.CEP_UNI_POST        + '",'
                     + '"' + objParametrosDeEntrada.N_CONTRATO          + '",'
                     + '"' + objParametrosDeEntrada.SEQUENCIA_OBJ       + '"';

            sComando := 'Insert into ' + objParametrosDeEntrada.tabela_processamento + ' (' + sCampos + ') values(' + sValues + ')';
            objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 1);

          end;

        end;

      end;
      CloseFile(flArquivoEntrada);

      COMPACTAR_ARQUIVO(sPathEntrada + sArquivoEntradaCIF, ExtractFilePath(sPathEntrada + sArquivoEntradaCIF), True, True);

//      DeleteFile(sPathEntrada + sArquivoEntradaCIF);

//    end;

  end;

  //========================================================================================================================================
  //  PRIMEIRO E ULTIMO OBJETO
  //========================================================================================================================================
    sComando := 'SELECT MIN(SEQUENCIA_OBJ) AS PRIMEIRO, MAX(SEQUENCIA_OBJ) AS ULTIMO FROM ' + objParametrosDeEntrada.TABELA_PROCESSAMENTO
              + ' GROUP BY CARTAO ';
    objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

   IF __queryMySQL_processamento__.RecordCount > 0 THEN
   begin

     sPRIMEIRO_OBJ := __queryMySQL_processamento__.FieldByName('PRIMEIRO').AsString;
     sULTIMO_OBJ   := __queryMySQL_processamento__.FieldByName('ULTIMO').AsString;

   end;


  //======================================================
  //  LISTA DE PESOS POR COLUNA
  //======================================================
  stlLOCAL_PesoUnitario        := TStringList.Create();
  stlLOCAL_Quantidades         := TStringList.Create();
  stlLOCAL_Totais              := TStringList.Create();

  stlESTADUAL_PesoUnitario        := TStringList.Create();
  stlESTADUAL_Quantidades         := TStringList.Create();
  stlESTADUAL_Totais              := TStringList.Create();

  stlNACIONAL_PesoUnitario        := TStringList.Create();
  stlNACIONAL_Quantidades         := TStringList.Create();
  stlNACIONAL_Totais              := TStringList.Create();
  //======================================================

  //========================================================================================================================================
  //  APURANDO LISTA DE CARTAO
  //========================================================================================================================================
    sComando := 'SELECT CARTAO FROM ' + objParametrosDeEntrada.TABELA_PROCESSAMENTO
              + ' GROUP BY CARTAO ';
    objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

  stlListaDeNCartao.Clear;
  while not __queryMySQL_processamento__.Eof do
  begin
    stlListaDeNCartao.Add(__queryMySQL_processamento__.FieldByName('CARTAO').AsString);
    __queryMySQL_processamento__.Next;
  end; // END WHILE
  //========================================================================================================================================


  //========================================================================================================================================
  //  CRIANDO LISTA POR N DE CARTAO
  //========================================================================================================================================
  Lista             := TQRprinter.Create;
  Lista.Orientation := poPortrait;
  Lista.BeginDoc;

  FOR iContNumeroContratos := 0 to stlListaDeNCartao.Count - 1 do
  Begin

    //=================================================
    // INCREMENTA O LOTE CASO TENHA MAIS DE UMA LISTA
    //=================================================
    if iContNumeroContratos > 0 then
      objParametrosDeEntrada.PEDIDO_LOTE := FormatFloat( objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO, StrToInt(objParametrosDeEntrada.PEDIDO_LOTE) + 1);
    //=================================================

    sNumeroDeCartao := stlListaDeNCartao.Strings[iContNumeroContratos];

    //===============================================================================================
    //  APURANDO LISTA DE CARTAO
    //===============================================================================================
    sComando := 'SELECT COD_CATEGORIA FROM ' + objParametrosDeEntrada.TABELA_PROCESSAMENTO
              + ' WHERE CARTAO = "' + sNumeroDeCartao + '"'
              + ' GROUP BY COD_CATEGORIA ';
    objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

    TIPO_FAC        := '';
    IMG_FOLHA_UNICA := '';
    bFacRegistrado  := False;
    stlCategorias.Clear;
    while not __queryMySQL_processamento__.Eof do
    begin

      stlCategorias.Add(__queryMySQL_processamento__.FieldByName('COD_CATEGORIA').AsString);

      IF (
            (__queryMySQL_processamento__.FieldByName('COD_CATEGORIA').AsString = '82015')
         OR (__queryMySQL_processamento__.FieldByName('COD_CATEGORIA').AsString = '82023')
         OR (__queryMySQL_processamento__.FieldByName('COD_CATEGORIA').AsString = '82031')
      ) THEN
      BEGIN

        bFacRegistrado  := False;

        IMG_FOLHA_UNICA := objParametrosDeEntrada.IMAGEM_UNICA;
        IMG_FOLHA_01    := objParametrosDeEntrada.IMAGEM_PG1;
        IMG_FOLHA_0N    := objParametrosDeEntrada.IMAGEM_PGN;

        TIPO_FAC := 'FAC SIMPES';

        CODIGO_SERVICO_LOCAL     := '8201-5 FAC SIMPLES LOCAL';
        CODIGO_SERVICO_ESTADUAL  := '8202-3 FAC SIMPES ESTADUAL';
        CODIGO_SERVICO_NACIONAL  := '8203-1 FAC SIMPLES NACIONAL';

      end;

      IF (
            (__queryMySQL_processamento__.FieldByName('COD_CATEGORIA').AsString = '82104')
         OR (__queryMySQL_processamento__.FieldByName('COD_CATEGORIA').AsString = '82112')
         OR (__queryMySQL_processamento__.FieldByName('COD_CATEGORIA').AsString = '82120')
      ) THEN
      BEGIN

        bFacRegistrado  := True;

        IMG_FOLHA_UNICA := objParametrosDeEntrada.IMAGEM_UNICA_FAC_REGISTRADO;
        IMG_FOLHA_01    := objParametrosDeEntrada.IMAGEM_PG1_FAC_REGISTRADO;
        IMG_FOLHA_0N    := objParametrosDeEntrada.IMAGEM_PGN_FAC_REGISTRADO;

        TIPO_FAC := 'FAC REGISTRADO';

        CODIGO_SERVICO_LOCAL     := '8210-4 FAC REGISTRADO LOCAL';
        CODIGO_SERVICO_ESTADUAL  := '8211-2 FAC REGISTRADO ESTADUAL';
        CODIGO_SERVICO_NACIONAL  := '8212-0 FAC REGISTRADO NACIONAL';

      end;

      IF (
            (__queryMySQL_processamento__.FieldByName('COD_CATEGORIA').AsString = '82139')
         OR (__queryMySQL_processamento__.FieldByName('COD_CATEGORIA').AsString = '82147')
         OR (__queryMySQL_processamento__.FieldByName('COD_CATEGORIA').AsString = '82155')

      ) THEN
      BEGIN

        bFacRegistrado  := True;

        IMG_FOLHA_UNICA := objParametrosDeEntrada.IMAGEM_UNICA_FAC_REGISTRADO;
        IMG_FOLHA_01    := objParametrosDeEntrada.IMAGEM_PG1_FAC_REGISTRADO;
        IMG_FOLHA_0N    := objParametrosDeEntrada.IMAGEM_PGN_FAC_REGISTRADO;

        TIPO_FAC := 'FAC REGISTRADO COM AR';

        CODIGO_SERVICO_LOCAL     := '8213-9 FAC REGISTRADO LOCAL';
        CODIGO_SERVICO_ESTADUAL  := '8214-7 FAC REGISTRADO ESTADUAL';
        CODIGO_SERVICO_NACIONAL  := '8215-5 FAC REGISTRADO NACIONAL';

      end;


      //========================================================================
      //  GPOST
      //========================================================================

      IF (
         //GPOST
            (__queryMySQL_processamento__.FieldByName('COD_CATEGORIA').AsString = '84107')
         OR (__queryMySQL_processamento__.FieldByName('COD_CATEGORIA').AsString = '84093')
         OR (__queryMySQL_processamento__.FieldByName('COD_CATEGORIA').AsString = '84085')

      ) THEN
      BEGIN

        bFacRegistrado  := False;

        IMG_FOLHA_UNICA := objParametrosDeEntrada.IMAGEM_UNICA;
        IMG_FOLHA_01    := objParametrosDeEntrada.IMAGEM_PG1;
        IMG_FOLHA_0N    := objParametrosDeEntrada.IMAGEM_PGN;

        TIPO_FAC := 'FAC SIMPES';

        CODIGO_SERVICO_LOCAL     := '8410-7 FAC SIMPLES LOCAL';
        CODIGO_SERVICO_ESTADUAL  := '8409-3 FAC SIMPES ESTADUAL';
        CODIGO_SERVICO_NACIONAL  := '8408-5 FAC SIMPLES NACIONAL';

      end;

      IF (
            (__queryMySQL_processamento__.FieldByName('COD_CATEGORIA').AsString = '84077')
         OR (__queryMySQL_processamento__.FieldByName('COD_CATEGORIA').AsString = '84069')
         OR (__queryMySQL_processamento__.FieldByName('COD_CATEGORIA').AsString = '84050')
      ) THEN
      BEGIN

        bFacRegistrado  := True;

        IMG_FOLHA_UNICA := objParametrosDeEntrada.IMAGEM_UNICA_FAC_REGISTRADO;
        IMG_FOLHA_01    := objParametrosDeEntrada.IMAGEM_PG1_FAC_REGISTRADO;
        IMG_FOLHA_0N    := objParametrosDeEntrada.IMAGEM_PGN_FAC_REGISTRADO;

        TIPO_FAC := 'FAC REGISTRADO';

        CODIGO_SERVICO_LOCAL     := '8407-7 FAC REGISTRADO LOCAL';
        CODIGO_SERVICO_ESTADUAL  := '8406-9 FAC REGISTRADO ESTADUAL';
        CODIGO_SERVICO_NACIONAL  := '8405-0 FAC REGISTRADO NACIONAL';

      end;


      IF (
            (__queryMySQL_processamento__.FieldByName('COD_CATEGORIA').AsString = '84034')
         OR (__queryMySQL_processamento__.FieldByName('COD_CATEGORIA').AsString = '84026')
         OR (__queryMySQL_processamento__.FieldByName('COD_CATEGORIA').AsString = '84018')

      ) THEN
      BEGIN

        bFacRegistrado  := True;

        IMG_FOLHA_UNICA := objParametrosDeEntrada.IMAGEM_UNICA_FAC_REGISTRADO;
        IMG_FOLHA_01    := objParametrosDeEntrada.IMAGEM_PG1_FAC_REGISTRADO;
        IMG_FOLHA_0N    := objParametrosDeEntrada.IMAGEM_PGN_FAC_REGISTRADO;

        TIPO_FAC := 'FAC REGISTRADO COM AR';

        CODIGO_SERVICO_LOCAL     := '8403-4 FAC REGISTRADO LOCAL';
        CODIGO_SERVICO_ESTADUAL  := '8402-6 FAC REGISTRADO ESTADUAL';
        CODIGO_SERVICO_NACIONAL  := '8401-8 FAC REGISTRADO NACIONAL';

      end;





      __queryMySQL_processamento__.Next;
    end; // END WHILE
    //===============================================================================================

    //===============================================================================================
    //  APURANDO LISTA DE CARTAO
    //===============================================================================================
    sComando := 'SELECT distinct(LOTE) FROM ' + objParametrosDeEntrada.TABELA_PROCESSAMENTO
              + ' WHERE CARTAO = "' + sNumeroDeCartao + '"'
              + ' ORDER BY LOTE';
    objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

    stlListaDeLotes.Clear;
    while not __queryMySQL_processamento__.Eof do
    begin
      stlListaDeLotes.Add(__queryMySQL_processamento__.FieldByName('LOTE').AsString);
      __queryMySQL_processamento__.Next;
    end; //END WHILE
    //===============================================================================================

    iContLinhasLOCAL      := 0;
    iContLinhasESTADUAL      := 0;
    iContLinhasNACIONAL      := 0;
    iTotalDeLinhasLista   := 0;
    iTotalDePaginas       := 0;

    i82015QuantidadeTotal := 0;
    i82023QuantidadeTotal := 0;
    i82031QuantidadeTotal := 0;

    d82015PesoTotal       := 0;
    d82023PesoTotal       := 0;
    d82031PesoTotal       := 0;

    FOR iContCategoria := 0 TO stlCategorias.Count - 1 do
    begin

      sCodigoCategoria := stlCategorias.Strings[iContCategoria];

      //===============================================================================================
      //  APURANDO LISTA DE CARTAO
      //===============================================================================================
      sComando := 'SELECT PESO_UNITARIO, COUNT(COD_CATEGORIA) AS QUANTIDADE, SUM(PESO_UNITARIO) AS PESO FROM ' + objParametrosDeEntrada.TABELA_PROCESSAMENTO
                + ' WHERE CARTAO        = "' + sNumeroDeCartao  + '"'
                + '   AND COD_CATEGORIA = "' + sCodigoCategoria + '"'
                + ' GROUP BY PESO_UNITARIO '
                + ' ORDER BY PESO_UNITARIO ';
      objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

      if __queryMySQL_processamento__.RecordCount > 0 then
      begin

        while not __queryMySQL_processamento__.Eof do
        begin

          if  (sCodigoCategoria = '82015')
           or (sCodigoCategoria = '82104')
           or (sCodigoCategoria = '82139')
           or (sCodigoCategoria = '84107')  // GPOST FAC LOCAL SIMPLES
           or (sCodigoCategoria = '84077')  // GPOST FAC LOCAL REGISTRADO
           or (sCodigoCategoria = '84034')  // GPOST FAC LOCAL REGISTRADO COM AR
          then
          begin

            sQuantidade := FormatFloat('#,##', __queryMySQL_processamento__.FieldByName('QUANTIDADE').AsInteger);
            sPeso       := FormatFloat('#,##0.00', __queryMySQL_processamento__.FieldByName('PESO').AsFloat);

            stlLOCAL_PesoUnitario.Add(__queryMySQL_processamento__.FieldByName('PESO_UNITARIO').AsString);
            stlLOCAL_Quantidades.Add(sQuantidade);
            stlLOCAL_Totais.Add(sPeso);

            i82015QuantidadeTotal := i82015QuantidadeTotal + __queryMySQL_processamento__.FieldByName('QUANTIDADE').AsInteger;
            d82015PesoTotal       := d82015PesoTotal       + __queryMySQL_processamento__.FieldByName('PESO').AsFloat;

            Inc(iContLinhasLOCAL);

          end;

          if  (sCodigoCategoria = '82023')
           or (sCodigoCategoria = '82112')
           or (sCodigoCategoria = '82147')
           or (sCodigoCategoria = '84093') // GPOST FAC ESTADUAL SIMPLES
           or (sCodigoCategoria = '84069') // GPOST FAC ESTADUAL REGISTRADO
           or (sCodigoCategoria = '84026') // GPOST FAC ESTADUAL REGISTRADO COM AR
          then
          begin

            sQuantidade := FormatFloat('#,##', __queryMySQL_processamento__.FieldByName('QUANTIDADE').AsInteger);
            sPeso       := FormatFloat('#,##0.00', __queryMySQL_processamento__.FieldByName('PESO').AsFloat);

            stlESTADUAL_PesoUnitario.Add(__queryMySQL_processamento__.FieldByName('PESO_UNITARIO').AsString);
            stlESTADUAL_Quantidades.Add(sQuantidade);
            stlESTADUAL_Totais.Add(sPeso);

            i82023QuantidadeTotal := i82023QuantidadeTotal + __queryMySQL_processamento__.FieldByName('QUANTIDADE').AsInteger;
            d82023PesoTotal       := d82023PesoTotal       + __queryMySQL_processamento__.FieldByName('PESO').AsFloat;

            Inc(iContLinhasESTADUAL);

          end;

          if  (sCodigoCategoria = '82031')
           or (sCodigoCategoria = '82120')
           or (sCodigoCategoria = '82155')
           or (sCodigoCategoria = '84085') // GPOST FAC NACIONAL SIMPLES
           or (sCodigoCategoria = '84050') // GPOST FAC NACIONAL REGISTRADO
           or (sCodigoCategoria = '84018') // GPOST FAC NACIONAL REGISTRADO COM AR
          then
          begin

            sQuantidade := FormatFloat('#,##', __queryMySQL_processamento__.FieldByName('QUANTIDADE').AsInteger);
            sPeso       := FormatFloat('#,##0.00', __queryMySQL_processamento__.FieldByName('PESO').AsFloat);

            stlNACIONAL_PesoUnitario.Add(__queryMySQL_processamento__.FieldByName('PESO_UNITARIO').AsString);
            stlNACIONAL_Quantidades.Add(sQuantidade);
            stlNACIONAL_Totais.Add(sPeso);

            i82031QuantidadeTotal := i82031QuantidadeTotal + __queryMySQL_processamento__.FieldByName('QUANTIDADE').AsInteger;
            d82031PesoTotal       := d82031PesoTotal       + __queryMySQL_processamento__.FieldByName('PESO').AsFloat;

            Inc(iContLinhasNACIONAL);

          end;

          __queryMySQL_processamento__.Next;
        end;

        if iContLinhasLOCAL > iTotalDeLinhasLista then
          iTotalDeLinhasLista := iContLinhasLOCAL;

        if iContLinhasESTADUAL > iTotalDeLinhasLista then
          iTotalDeLinhasLista := iContLinhasESTADUAL;

        if iContLinhasNACIONAL > iTotalDeLinhasLista then
          iTotalDeLinhasLista := iContLinhasNACIONAL;

      end;

    end;

    iContLinhaPorPagina := 0;

    //==================================================================
    //  VERIFICA QUANTAS PAGINAS SERÃO USADAS
    //==================================================================
    if iTotalDeLinhasLista <= 24 then
      iTotalDePaginas := 1
    else
    if (iTotalDeLinhasLista > 24) and (iTotalDeLinhasLista <= 37) then
      iTotalDePaginas := 2
    else
    if (iTotalDeLinhasLista mod 37) > 0 then
      iTotalDePaginas := (iTotalDeLinhasLista div 37) + 1
    else
      iTotalDePaginas := (iTotalDeLinhasLista div 37);
    //==================================================================

    Lista.NewPage;
    //img:=TImage.Create(Application);
    Image := TBitmap.Create();

    if iTotalDePaginas > 1 then
    Begin
      //img.Picture.LoadFromFile(IMG_FOLHA_01)
      Image.LoadFromFile(IMG_FOLHA_01);
    end
    else
    Begin
      //img.Picture.LoadFromFile(IMG_FOLHA_UNICA);
      Image.LoadFromFile(IMG_FOLHA_UNICA);
    end;

    Image.PixelFormat := pf24bit;

    //Lista.Canvas.StretchDraw(Rect(30,30,780,1100),img.Picture.Graphic);
    Lista.Canvas.StretchDraw(Rect(30,30,780,1100), Image);



    //=======================================================================================================================================================================================
    //  DADOS DO CABEÇALHO
    //=======================================================================================================================================================================================
    Lista.Canvas.Font.Name := 'Arial';
    Lista.Canvas.Font.Size := 13;

    if StrToInt(objParametrosDeEntrada.PEDIDO_LOTE_MANUAL) = 0 then
      LISTA.Canvas.TextOut(480 , 50, FormatFloat(objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO, StrToInt(objParametrosDeEntrada.PEDIDO_LOTE)) + '/' + FormatDateTime('YYYY', Now()) )
    else
      LISTA.Canvas.TextOut(480 , 50, FormatFloat(objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO, StrToInt(objParametrosDeEntrada.PEDIDO_LOTE_MANUAL)) + '/' + FormatDateTime('YYYY', Now()));

    Lista.Canvas.Font.Size := 10;
    LISTA.Canvas.TextOut(670, 52 , objParametrosDeEntrada.DATA_POSTAGEM);
    //=======================================================================================================================================================================================

    sComando := 'SELECT * FROM ' + objParametrosDeEntrada.TABELA_PROCESSAMENTO
              + ' where CARTAO = "' + sNumeroDeCartao + '"'
              + ' group by CARTAO ';
    objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

    //====================================================================================
    //                               LABEL COM TIPO DE FAC
    //====================================================================================
    Lista.Canvas.Font.Style := [fsBold];
    Lista.Canvas.Font.Size := 9;
    LISTA.Canvas.TextOut(248 , 040,     'LISTA DE POSTAGEM');
    LISTA.Canvas.TextOut(248 , 040 + 12, TIPO_FAC);
    Lista.Canvas.Font.Style := [];
    //====================================================================================

    Lista.Canvas.Font.Size := 7;
    LISTA.Canvas.TextOut(320, 085, 'BANCO BRADESCO');
    LISTA.Canvas.TextOut(80,  120, __queryMySQL_processamento__.FieldByName('N_CONTRATO').AsString);
    LISTA.Canvas.TextOut(340, 120, __queryMySQL_processamento__.FieldByName('CODIGO_ADM_CONTRATO').AsString);
    LISTA.Canvas.TextOut(600, 120, __queryMySQL_processamento__.FieldByName('CARTAO').AsString);

    LISTA.Canvas.TextOut(80,  148, 'SPM');
    LISTA.Canvas.TextOut(150, 148, 'SÃO PAULO');
    LISTA.Canvas.TextOut(320, 148, 'GCCAP 3 CTC JAGUARÉ/SPM');
    LISTA.Canvas.TextOut(600, 148, '00425791');
    LISTA.Canvas.TextOut(250, 176, 'FINGERPRINT GRAFICA LTDA');
    LISTA.Canvas.TextOut(600, 176, '72.945.587/0004-65');

    //====================================================================================
    //                                DESCONTOS
    //====================================================================================

    //====================================================================================

    //====================================================================================
    //                              PRÉ REQUISITOS
    //====================================================================================
    Lista.Canvas.Font.Name := 'Courier New';
    Lista.Canvas.Font.Size := 6;
    if not objParametrosDeEntrada.FAC_REGISTRADO then
    Begin
      LISTA.Canvas.TextOut(410, 213, '- CEP/ENDEREÇO COMPLETO E CORRETO........');
      LISTA.Canvas.TextOut(410, 223, '- PLANO DE TRIAGEN/ BLOCAGEM.............');
      LISTA.Canvas.TextOut(410, 233, '- CHANCELA DE FRANQUEAMENTO..............');
      LISTA.Canvas.TextOut(410, 244, '- CÓDIGO CIF.............................');
      LISTA.Canvas.TextOut(410, 254, '- RPE E LP...............................');
      LISTA.Canvas.TextOut(410, 264, '- CEPNET EM OBJETO AUTOMATIZAVEL.........');
      LISTA.Canvas.TextOut(410, 274, '- CARGA UNITIZADA........................');
    end
    ELSE
    if objParametrosDeEntrada.FAC_REGISTRADO then
    Begin
      LISTA.Canvas.TextOut(410, 213, '- CEP/ENDEREÇO COMPLETO E CORRETO........');
      LISTA.Canvas.TextOut(410, 223, '- PLANO DE TRIAGEN/ BLOCAGEM.............');
      LISTA.Canvas.TextOut(410, 233, '- CHANCELA DE FRANQUEAMENTO..............');
      LISTA.Canvas.TextOut(410, 244, '- REGISTRO EM CÓDIGO DE BARRAS...........');
      LISTA.Canvas.TextOut(410, 254, '- RPE E LP...............................');
      LISTA.Canvas.TextOut(410, 264, '- CARGA UNITIZADA........................');
    end;

    Lista.Canvas.Font.Name := 'Arial';

    //====================================================================================

    //====================================================================================
    //                                DESCONTOS
    //====================================================================================
    if not objParametrosDeEntrada.FAC_REGISTRADO then
    begin
      Lista.Canvas.Font.Size := 7;
      LISTA.Canvas.TextOut(120, 190, '94 - CÓD. 2D OBJ AUTOMAT COM CEPNET:');

      Lista.Canvas.Font.Size := 5;
      LISTA.Canvas.TextOut(33, 205, 'CORREIOS - CARIMBO / ASSINATURA / MATRÍCULA / VALIDAÇÃO DOS PRÉ-REQUISITOS E DESCONTOS');
    end
    else
    begin
      Lista.Canvas.Font.Size := 5;
      LISTA.Canvas.TextOut(33, 190, 'CORREIOS - CARIMBO / ASSINATURA / MATRÍCULA / VALIDAÇÃO DOS PRÉ-REQUISITOS E DESCONTOS');
    end;
    //====================================================================================

    //====================================================================================
    //                       IMPRIMINDO RANGE DE OBJETOS
    //====================================================================================
    IF Pos('FAC REGISTRADO', TIPO_FAC) > 0 THEN
    begin

      Lista.Canvas.Moveto(32, 278);
      Lista.Canvas.LineTo(405, 278);

      Lista.Canvas.Font.Style := [fsBold];
      Lista.Canvas.Font.Size := 9;
      LISTA.Canvas.TextOut(50, 287, 'FAIXA DE REGISTRO');

      Lista.Canvas.Moveto(180, 278);
      Lista.Canvas.LineTo(180, 309);

      Lista.Canvas.Font.Name := 'Courier New';
      Lista.Canvas.Font.Size := 8;
      LISTA.Canvas.TextOut(200, 280, 'INICIAL..: ' + Copy(sPRIMEIRO_OBJ, 1, 10) + '-' + Copy(sPRIMEIRO_OBJ, 11, 1) + 'BR');
      LISTA.Canvas.TextOut(200, 293, 'FINAL....: ' + Copy(sULTIMO_OBJ,   1, 10) + '-' + Copy(sULTIMO_OBJ,   11, 1) + 'BR');
      Lista.Canvas.Font.Name := 'arial';

    end;
    //====================================================================================


    //====================================================================================
    //  LABEL DE CÓDIGO E DESCRIÇÃO DAS DIREÇÕES
    //====================================================================================

    // LOCAL

    xDesloc                   := 0;

    Lista.Canvas.Font.Style := [fsBold];
    Lista.Canvas.Font.Size := 9;
    LISTA.Canvas.TextOut(60 + 12 + xDesloc, 312,      CODIGO_SERVICO_LOCAL);

    // ESTADUAL

    xDesloc                   := 240;

    Lista.Canvas.Font.Style := [fsBold];
    Lista.Canvas.Font.Size := 9;
    LISTA.Canvas.TextOut(40 + 12 + xDesloc, 312,      CODIGO_SERVICO_ESTADUAL);

    // NACIONAL

    xDesloc                   := 495;

    Lista.Canvas.Font.Style := [fsBold];
    Lista.Canvas.Font.Size := 9;
    LISTA.Canvas.TextOut(40 + 12 + xDesloc, 312,      CODIGO_SERVICO_NACIONAL);

    Lista.Canvas.Font.Style := [];
    //====================================================================================


    //====================================================================================
    //  LABEL DE PESOS E QUANTIDADES
    //====================================================================================
    // LOCAL

    xDesloc                   := 0;
    xDesloc2                  := 0;

    Lista.Canvas.Font.Style := [];
    Lista.Canvas.Font.Size := 5;
    LISTA.Canvas.TextOut(40 + 12 + xDesloc, 335,      'PESO');
    LISTA.Canvas.TextOut(40 + 00 + xDesloc, 335 + 10, 'UNITÁRIO (g)*');

    if bFacRegistrado then
    begin
      Lista.Canvas.Font.Style := [];
      Lista.Canvas.Font.Size := 5;
      LISTA.Canvas.TextOut(103 + 00 + xDesloc, 335,      'QTDE');
      LISTA.Canvas.TextOut(105 + 00 + xDesloc, 335 + 10, 'OBJ');

      Lista.Canvas.Font.Style := [];
      Lista.Canvas.Font.Size := 5;
      LISTA.Canvas.TextOut(146 + 00 + xDesloc , 335,      'PESO');
      LISTA.Canvas.TextOut(141 + 00 + xDesloc , 345,      'TOTAL (g)');

      Lista.Canvas.Font.Style := [];
      Lista.Canvas.Font.Size := 5;
      LISTA.Canvas.TextOut(198 + 00 + xDesloc, 340,      'MP');


      Lista.Canvas.Font.Style := [];
      Lista.Canvas.Font.Size := 5;
      LISTA.Canvas.TextOut(226 + 00 + xDesloc, 331,      'VALOR');
      LISTA.Canvas.TextOut(219 + 00 + xDesloc, 339,      'DECLARADO');
      LISTA.Canvas.TextOut(215 + 00 + xDesloc, 348,      'UNITARIO (R$)');

    end
    else
    begin
      Lista.Canvas.Font.Style := [];
      Lista.Canvas.Font.Size := 5;
      LISTA.Canvas.TextOut(115 + 00 + xDesloc + xDesloc2, 335,      'QUANTIDADE');
      LISTA.Canvas.TextOut(115 + 00 + xDesloc + xDesloc2, 335 + 10, 'DE OBJETOS');

      Lista.Canvas.Font.Style := [];
      Lista.Canvas.Font.Size := 5;
      LISTA.Canvas.TextOut(195 + 00 + xDesloc + xDesloc2, 340,      'PESO TOTAL (g)');
    end;


    // ESTADUAL

    xDesloc                   := 245;

    Lista.Canvas.Font.Style := [];
    Lista.Canvas.Font.Size := 5;
    LISTA.Canvas.TextOut(40 + 12 + xDesloc, 335,      'PESO');
    LISTA.Canvas.TextOut(40 + 00 + xDesloc, 335 + 10, 'UNITÁRIO (g)*');

    if bFacRegistrado then
    begin
      Lista.Canvas.Font.Style := [];
      Lista.Canvas.Font.Size := 5;
      LISTA.Canvas.TextOut(103 + 00 + xDesloc, 335,      'QTDE');
      LISTA.Canvas.TextOut(105 + 00 + xDesloc, 335 + 10, 'OBJ');

      Lista.Canvas.Font.Style := [];
      Lista.Canvas.Font.Size := 5;
      LISTA.Canvas.TextOut(152 + 00 + xDesloc , 335,      'PESO');
      LISTA.Canvas.TextOut(147 + 00 + xDesloc , 345,      'TOTAL (g)');

      Lista.Canvas.Font.Style := [];
      Lista.Canvas.Font.Size := 5;
      LISTA.Canvas.TextOut(205 + 00 + xDesloc, 340,      'MP');


      Lista.Canvas.Font.Style := [];
      Lista.Canvas.Font.Size := 5;
      LISTA.Canvas.TextOut(233 + 00 + xDesloc, 331,      'VALOR');
      LISTA.Canvas.TextOut(226 + 00 + xDesloc, 339,      'DECLARADO');
      LISTA.Canvas.TextOut(222 + 00 + xDesloc, 348,      'UNITARIO (R$)');

    end
    else
    begin

      Lista.Canvas.Font.Style := [];
      Lista.Canvas.Font.Size := 5;
      LISTA.Canvas.TextOut(115 + 00 + xDesloc, 335,      'QUANTIDADE');
      LISTA.Canvas.TextOut(115 + 00 + xDesloc, 335 + 10, 'DE OBJETOS');

      Lista.Canvas.Font.Style := [];
      Lista.Canvas.Font.Size := 5;
      LISTA.Canvas.TextOut(195 + 00 + xDesloc, 340,      'PESO TOTAL (g)');
    end;

    // NACIONAL

    xDesloc                   := 495;

    Lista.Canvas.Font.Style := [];
    Lista.Canvas.Font.Size := 5;
    LISTA.Canvas.TextOut(40 + 12 + xDesloc, 335,      'PESO');
    LISTA.Canvas.TextOut(40 + 00 + xDesloc, 335 + 10, 'UNITÁRIO (g)*');

    if bFacRegistrado then
    BEGIN
      Lista.Canvas.Font.Style := [];
      Lista.Canvas.Font.Size := 5;
      LISTA.Canvas.TextOut(103 + 00 + xDesloc, 335,      'QTDE');
      LISTA.Canvas.TextOut(105 + 00 + xDesloc, 335 + 10, 'OBJ');

      Lista.Canvas.Font.Style := [];
      Lista.Canvas.Font.Size := 5;
      LISTA.Canvas.TextOut(152 + 00 + xDesloc , 335,      'PESO');
      LISTA.Canvas.TextOut(147 + 00 + xDesloc , 345,      'TOTAL (g)');

      Lista.Canvas.Font.Style := [];
      Lista.Canvas.Font.Size := 5;
      LISTA.Canvas.TextOut(207 + 00 + xDesloc, 340,      'MP');


      Lista.Canvas.Font.Style := [];
      Lista.Canvas.Font.Size := 5;
      LISTA.Canvas.TextOut(235 + 00 + xDesloc, 331,      'VALOR');
      LISTA.Canvas.TextOut(228 + 00 + xDesloc, 339,      'DECLARADO');
      LISTA.Canvas.TextOut(224 + 00 + xDesloc, 348,      'UNITARIO (R$)');
    end
    else
    BEGIN

      Lista.Canvas.Font.Style := [];
      Lista.Canvas.Font.Size := 5;
      LISTA.Canvas.TextOut(115 + 00 + xDesloc, 335,      'QUANTIDADE');
      LISTA.Canvas.TextOut(115 + 00 + xDesloc, 335 + 10, 'DE OBJETOS');

      Lista.Canvas.Font.Style := [];
      Lista.Canvas.Font.Size := 5;
      LISTA.Canvas.TextOut(195 + 00 + xDesloc, 340,      'PESO TOTAL (g)');
    end;
    //====================================================================================


    yDesloc                   := 0;
    xDesloc                   := 0;
    xDesloc2                  := 0;
    iAjusteLinha              := 0;
    iContLinhasNaPagina       := 0;
    iLimiteDeLinhasPorPaginas := 37;
    iContPagina               := 0;

    if bFacRegistrado then
      xDesloc2 := - 60;

    for iContLinhas := 0 to iTotalDeLinhasLista -1 do
    begin

      Lista.Canvas.Font.Size := 7;

      if iContLinhas <= stlLOCAL_PesoUnitario.Count -1 then
      begin

        xDesloc := 0;

        LISTA.Canvas.TextOut(55  + xDesloc           , 361 + yDesloc + iAjusteLinha, stlLOCAL_PesoUnitario.Strings[iContLinhas]);
        LISTA.Canvas.TextOut(115 + xDesloc           , 361 + yDesloc + iAjusteLinha, stlLOCAL_Quantidades.Strings[iContLinhas]);
        LISTA.Canvas.TextOut(195 + xDesloc + xDesloc2, 361 + yDesloc + iAjusteLinha, stlLOCAL_Totais.Strings[iContLinhas]);

      end;

      if iContLinhas <= stlESTADUAL_PesoUnitario.Count -1 then
      begin

        xDesloc := 240;

        LISTA.Canvas.TextOut(55  + xDesloc           , 361 + yDesloc + iAjusteLinha, stlESTADUAL_PesoUnitario.Strings[iContLinhas]);
        LISTA.Canvas.TextOut(115 + xDesloc           , 361 + yDesloc + iAjusteLinha, stlESTADUAL_Quantidades.Strings[iContLinhas]);
        LISTA.Canvas.TextOut(205 + xDesloc + xDesloc2, 361 + yDesloc + iAjusteLinha, stlESTADUAL_Totais.Strings[iContLinhas]);

      end;

      if iContLinhas <= stlNACIONAL_PesoUnitario.Count -1 then
      begin

        xDesloc := 480;

        LISTA.Canvas.TextOut(55  + xDesloc           , 361 + yDesloc + iAjusteLinha, stlNACIONAL_PesoUnitario.Strings[iContLinhas]);
        LISTA.Canvas.TextOut(120 + xDesloc           , 361 + yDesloc + iAjusteLinha, stlNACIONAL_Quantidades.Strings[iContLinhas]);
        LISTA.Canvas.TextOut(215 + xDesloc + xDesloc2, 361 + yDesloc + iAjusteLinha, stlNACIONAL_Totais.Strings[iContLinhas]);

      end;

      yDesloc := yDesloc + 20;

      Inc(iContLinhasNaPagina);

      if  ((iContLinhasNaPagina >= iLimiteDeLinhasPorPaginas) and (iContLinhas <> iTotalDeLinhasLista -1))
       or ( (iTotalDeLinhasLista > 24) and (iTotalDeLinhasLista <= 37) and (iContLinhas = iTotalDeLinhasLista -1) and (iContPagina + 1 = 1) ) // QUANTO O TOTAL DE OBJETOS É IGUAL AO LIMITE DE MINHAS NA PRIMEIRA PÁGINA SEM RODAPÉ
      then
      begin

        Lista.NewPage;

        img:=TImage.Create(Application);
        img.Picture.LoadFromFile(IMG_FOLHA_0N);
        Lista.Canvas.StretchDraw(Rect(30,30,780,1100),img.Picture.Graphic);

        Lista.Canvas.Font.Name := 'arial';

        //====================================================================================
        //                               LABEL COM TIPO DE FAC
        //====================================================================================
        Lista.Canvas.Font.Style := [fsBold];
        Lista.Canvas.Font.Size := 9;
        LISTA.Canvas.TextOut(248 , 040,     'LISTA DE POSTAGEM');
        LISTA.Canvas.TextOut(248 , 040 + 12, TIPO_FAC);
        Lista.Canvas.Font.Style := [];
        //====================================================================================

        //====================================================================================
        //  LABEL DE CÓDIGO E DESCRIÇÃO DAS DIREÇÕES
        //====================================================================================

        // LOCAL

        xDesloc                   := 0;

        Lista.Canvas.Font.Style := [fsBold];
        Lista.Canvas.Font.Size := 9;
        LISTA.Canvas.TextOut(40 + 12 + xDesloc, 090,      CODIGO_SERVICO_LOCAL);

        // ESTADUAL

        xDesloc                   := 240;

        Lista.Canvas.Font.Style := [fsBold];
        Lista.Canvas.Font.Size := 9;
        LISTA.Canvas.TextOut(40 + 12 + xDesloc, 090,      CODIGO_SERVICO_ESTADUAL);

        // NACIONAL

        xDesloc                   := 495;

        Lista.Canvas.Font.Style := [fsBold];
        Lista.Canvas.Font.Size := 9;
        LISTA.Canvas.TextOut(40 + 12 + xDesloc, 090,      CODIGO_SERVICO_NACIONAL);
        Lista.Canvas.Font.Style := [];
        //====================================================================================

        //====================================================================================
        //  LABEL DE PESOS E QUANTIDADES
        //====================================================================================
        // LOCAL

        xDesloc                   := 0;

        Lista.Canvas.Font.Style := [];
        Lista.Canvas.Font.Size := 5;
        LISTA.Canvas.TextOut(40 + 12 + xDesloc, 114,      'PESO');
        LISTA.Canvas.TextOut(40 + 00 + xDesloc, 114 + 10, 'UNITÁRIO (g)*');

        if bFacRegistrado then
        begin
          Lista.Canvas.Font.Style := [];
          Lista.Canvas.Font.Size := 5;
          LISTA.Canvas.TextOut(103 + 00 + xDesloc, 114,      'QTDE');
          LISTA.Canvas.TextOut(105 + 00 + xDesloc, 114 + 10, 'OBJ');

          Lista.Canvas.Font.Style := [];
          Lista.Canvas.Font.Size := 5;
          LISTA.Canvas.TextOut(146 + 00 + xDesloc , 114,      'PESO');
          LISTA.Canvas.TextOut(141 + 00 + xDesloc , 114 + 10,      'TOTAL (g)');

          Lista.Canvas.Font.Style := [];
          Lista.Canvas.Font.Size := 5;
          LISTA.Canvas.TextOut(198 + 00 + xDesloc, 114,      'MP');


          Lista.Canvas.Font.Style := [];
          Lista.Canvas.Font.Size := 5;
          LISTA.Canvas.TextOut(226 + 00 + xDesloc, 114      -2,      'VALOR');
          LISTA.Canvas.TextOut(219 + 00 + xDesloc, 114 + 8  -2,      'DECLARADO');
          LISTA.Canvas.TextOut(215 + 00 + xDesloc, 114 + 16 -2,      'UNITARIO (R$)');

        end
        else
        begin
          Lista.Canvas.Font.Style := [];
          Lista.Canvas.Font.Size := 5;
          LISTA.Canvas.TextOut(115 + 00 + xDesloc + xDesloc2, 114,      'QUANTIDADE');
          LISTA.Canvas.TextOut(115 + 00 + xDesloc + xDesloc2, 114 + 10, 'DE OBJETOS');

          Lista.Canvas.Font.Style := [];
          Lista.Canvas.Font.Size := 5;
          LISTA.Canvas.TextOut(195 + 00 + xDesloc + xDesloc2, 114,      'PESO TOTAL (g)');
        end;


        // ESTADUAL

        xDesloc                   := 245;

        Lista.Canvas.Font.Style := [];
        Lista.Canvas.Font.Size := 5;
        LISTA.Canvas.TextOut(40 + 12 + xDesloc, 114,      'PESO');
        LISTA.Canvas.TextOut(40 + 00 + xDesloc, 114 + 10, 'UNITÁRIO (g)*');

        if bFacRegistrado then
        begin
          Lista.Canvas.Font.Style := [];
          Lista.Canvas.Font.Size := 5;
          LISTA.Canvas.TextOut(103 + 00 + xDesloc, 114,      'QTDE');
          LISTA.Canvas.TextOut(105 + 00 + xDesloc, 114 + 10, 'OBJ');

          Lista.Canvas.Font.Style := [];
          Lista.Canvas.Font.Size := 5;
          LISTA.Canvas.TextOut(152 + 00 + xDesloc , 114,      'PESO');
          LISTA.Canvas.TextOut(147 + 00 + xDesloc , 114,      'TOTAL (g)');

          Lista.Canvas.Font.Style := [];
          Lista.Canvas.Font.Size := 5;
          LISTA.Canvas.TextOut(205 + 00 + xDesloc, 114,      'MP');


          Lista.Canvas.Font.Style := [];
          Lista.Canvas.Font.Size := 5;
          LISTA.Canvas.TextOut(233 + 00 + xDesloc, 114      -2,      'VALOR');
          LISTA.Canvas.TextOut(226 + 00 + xDesloc, 114 + 08 -2,      'DECLARADO');
          LISTA.Canvas.TextOut(222 + 00 + xDesloc, 114 + 16 -2,      'UNITARIO (R$)');

        end
        else
        begin

          Lista.Canvas.Font.Style := [];
          Lista.Canvas.Font.Size := 5;
          LISTA.Canvas.TextOut(115 + 00 + xDesloc, 114,      'QUANTIDADE');
          LISTA.Canvas.TextOut(115 + 00 + xDesloc, 114 + 10, 'DE OBJETOS');

          Lista.Canvas.Font.Style := [];
          Lista.Canvas.Font.Size := 5;
          LISTA.Canvas.TextOut(195 + 00 + xDesloc, 114,      'PESO TOTAL (g)');
        end;

        // NACIONAL

        xDesloc                   := 495;

        Lista.Canvas.Font.Style := [];
        Lista.Canvas.Font.Size := 5;
        LISTA.Canvas.TextOut(40 + 12 + xDesloc, 114,      'PESO');
        LISTA.Canvas.TextOut(40 + 00 + xDesloc, 114 + 10, 'UNITÁRIO (g)*');

        if bFacRegistrado then
        BEGIN
          Lista.Canvas.Font.Style := [];
          Lista.Canvas.Font.Size := 5;
          LISTA.Canvas.TextOut(103 + 00 + xDesloc, 114,      'QTDE');
          LISTA.Canvas.TextOut(105 + 00 + xDesloc, 114 + 10, 'OBJ');

          Lista.Canvas.Font.Style := [];
          Lista.Canvas.Font.Size := 5;
          LISTA.Canvas.TextOut(152 + 00 + xDesloc , 114,      'PESO');
          LISTA.Canvas.TextOut(147 + 00 + xDesloc , 114,      'TOTAL (g)');

          Lista.Canvas.Font.Style := [];
          Lista.Canvas.Font.Size := 5;
          LISTA.Canvas.TextOut(207 + 00 + xDesloc, 114,      'MP');


          Lista.Canvas.Font.Style := [];
          Lista.Canvas.Font.Size := 5;
          LISTA.Canvas.TextOut(235 + 00 + xDesloc, 114      -2,      'VALOR');
          LISTA.Canvas.TextOut(228 + 00 + xDesloc, 114 + 08 -2,      'DECLARADO');
          LISTA.Canvas.TextOut(224 + 00 + xDesloc, 114 + 16 -2,      'UNITARIO (R$)');
        end
        else
        BEGIN

          Lista.Canvas.Font.Style := [];
          Lista.Canvas.Font.Size := 5;
          LISTA.Canvas.TextOut(115 + 00 + xDesloc, 114,      'QUANTIDADE');
          LISTA.Canvas.TextOut(115 + 00 + xDesloc, 114 + 10, 'DE OBJETOS');

          Lista.Canvas.Font.Style := [];
          Lista.Canvas.Font.Size := 5;
          LISTA.Canvas.TextOut(195 + 00 + xDesloc, 114,      'PESO TOTAL (g)');
        end;
        //====================================================================================



        //=======================================================================================================================================================================================
        //  DADOS DO CABEÇALHO
        //=======================================================================================================================================================================================
        Lista.Canvas.Font.Name := 'Arial';
        Lista.Canvas.Font.Size := 13;

        if StrToInt(objParametrosDeEntrada.PEDIDO_LOTE_MANUAL) = 0 then
          LISTA.Canvas.TextOut(480 , 50, FormatFloat(objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO, StrToInt(objParametrosDeEntrada.PEDIDO_LOTE)) + '/' + FormatDateTime('YYYY', Now()) )
        else
          LISTA.Canvas.TextOut(480 , 50, FormatFloat(objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO, StrToInt(objParametrosDeEntrada.PEDIDO_LOTE_MANUAL)) + '/' + FormatDateTime('YYYY', Now()));

        Lista.Canvas.Font.Size := 10;
        LISTA.Canvas.TextOut(670, 52 , objParametrosDeEntrada.DATA_POSTAGEM);
        //=======================================================================================================================================================================================

        yDesloc                   := -220;
        xDesloc                   := 0;

        iContLinhasNaPagina       := 0;
        iLimiteDeLinhasPorPaginas := 35;

        Inc(iContPagina);

      end;


    end;


    //====================================================================================================================================
    //  Total 82015
    //====================================================================================================================================
    xDesloc := 0;
    LISTA.Canvas.TextOut(100 + xDesloc             ,835, FormatFloat('#,##', i82015QuantidadeTotal));
    LISTA.Canvas.TextOut(200 + xDesloc  + xDesloc2 ,835, FormatFloat('#,##0.00', d82015PesoTotal));
    //====================================================================================================================================

    //====================================================================================================================================
    //  Total 82023
    //====================================================================================================================================
    xDesloc := 240;
    LISTA.Canvas.TextOut(100 + xDesloc             ,835, FormatFloat('#,##', i82023QuantidadeTotal));
    LISTA.Canvas.TextOut(200 + xDesloc  + xDesloc2 ,835, FormatFloat('#,##0.00', d82023PesoTotal));
    //====================================================================================================================================

    //====================================================================================================================================
    //  Total 82031
    //====================================================================================================================================
    xDesloc := 480;
    LISTA.Canvas.TextOut(115 + xDesloc             ,835, FormatFloat('#,##', i82031QuantidadeTotal));
    LISTA.Canvas.TextOut(215 + xDesloc  + xDesloc2 ,835, FormatFloat('#,##0.00', d82031PesoTotal));
    //====================================================================================================================================

    //====================================================================================================================================
    //  Total geral
    //====================================================================================================================================
    LISTA.Canvas.TextOut(600, 855, FormatFloat('#,##', i82015QuantidadeTotal + i82023QuantidadeTotal + i82031QuantidadeTotal));
    LISTA.Canvas.TextOut(600, 875, FormatFloat('#,##0.00', d82015PesoTotal + d82023PesoTotal + d82031PesoTotal));
    //====================================================================================================================================
            

    //=====================================
    // Observaçoes
    //=====================================
    Lista.Canvas.Font.Name := 'LUCIDA';
    Lista.Canvas.Font.Size := 6;
    LISTA.Canvas.TextOut(40 , 985, 'OBSERVAÇÕES: ' + objParametrosDeEntrada.OBSERVACOES);

    Lista.Canvas.Font.Size := 8;
    //=====================================

    //=====================================
    // IMPRIMINDO OS LOTES EM OBSERVAÇÕES
    //=====================================
    Lista.Canvas.Font.Size := 7;

    xDesloc := 0;
    yDesloc := 0;
    iLimiteDeLotesNaPagina := 159;//91;

    iLimiteLotes := 0;

    for iContLotes := 0 to stlListaDeLotes.Count - 1 do
    begin

      IF iNumeroDeLotesNaPagina  >= iLimiteDeLotesNaPagina THEN
      BEGIN

        Lista.NewPage;
        img_PG2 := TImage.Create(Application);
        img_PG2.Picture.LoadFromFile(objParametrosDeEntrada.IMAGEM_PG2);
        Lista.Canvas.StretchDraw(Rect(30,30,780,1100),img_PG2.Picture.Graphic);

        //=======================================================================================================================================================================================
        //  DADOS DO CABEÇALHO
        //=======================================================================================================================================================================================
        Lista.Canvas.Font.Name := 'Arial';
        Lista.Canvas.Font.Size := 13;

        if StrToInt(objParametrosDeEntrada.PEDIDO_LOTE_MANUAL) = 0 then
          LISTA.Canvas.TextOut(480 , 50, FormatFloat(objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO, StrToInt(objParametrosDeEntrada.PEDIDO_LOTE)) + '/' + FormatDateTime('YYYY', Now()) )
        else
          LISTA.Canvas.TextOut(480 , 50, FormatFloat(objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO, StrToInt(objParametrosDeEntrada.PEDIDO_LOTE_MANUAL)) + '/' + FormatDateTime('YYYY', Now()));

        Lista.Canvas.Font.Size := 10;
        LISTA.Canvas.TextOut(670, 52 , objParametrosDeEntrada.DATA_POSTAGEM);
        //=======================================================================================================================================================================================

        iDeslocYLinhaExtra := 93;
        for iContLinhasExtrasOG2 := 0 to 68 do
        begin

          Lista.Canvas.Moveto(32  , iDeslocYLinhaExtra);
          Lista.Canvas.LineTo(778 , iDeslocYLinhaExtra);

          iDeslocYLinhaExtra := iDeslocYLinhaExtra + 13;

        end; // END FOR


        Lista.Canvas.Font.Size := 7;

        iNumeroDeLotesNaPagina := 0;

        xDesloc                := 0;
        yDesloc                := 0;
        iLimiteLotes           := 0;
        yDeslocPg2             := -813;

        iLimiteDeLotesNaPagina := 804;

      end; // END IF

      if yDesloc = 0 then
      begin
        LISTA.Canvas.TextOut(93 + xDesloc, 894 + yDesloc + yDeslocPg2, stlListaDeLotes.Strings[iContLotes] + '-');
        iLimiteColunas := 21;
      end
      else
      Begin
        LISTA.Canvas.TextOut(45 + xDesloc, 894 + yDesloc + yDeslocPg2, stlListaDeLotes.Strings[iContLotes]+ '-');
        iLimiteColunas := 23;
      end;

      xDesloc      := xDesloc      + 31;
      iLimiteLotes := iLimiteLotes + 1;

      if iLimiteLotes >= iLimiteColunas then
      begin
        yDesloc      := yDesloc + 13;
        xDesloc      := 0;
        iLimiteLotes := 0;
      end;

      inc(iNumeroDeLotesNaPagina);

    end; // END FOR

  end;

  Lista.EndDoc;

  Lista.Preview;

  IF objParametrosDeEntrada.IMPRIMIR THEN
  for iContImpressoes := 0 to StrToInt(objParametrosDeEntrada.NUMERO_DE_IMPRESSOES) -1 do
    Lista.print;







  {*
  if iTotalDePaginas = 0 then
  begin


      //===================================
      //  CRIANDO LISTA POR N DE CARTAO
      //===================================
      Lista             := TQRprinter.Create;
      Lista.Orientation := poPortrait;
      Lista.BeginDoc;

      FOR iContNumeroContratos := 0 to stlListaDeNCartao.Count - 1 do
      Begin

        //=================================================
        // INCREMENTA O LOTE CASO TENHA MAIS DE UMA LISTA
        //=================================================
        if iContNumeroContratos > 0 then
          objParametrosDeEntrada.PEDIDO_LOTE := FormatFloat( objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO, StrToInt(objParametrosDeEntrada.PEDIDO_LOTE) + 1);
        //=================================================

        sNumeroDeCartao := stlListaDeNCartao.Strings[iContNumeroContratos];

        Lista.NewPage;

        img:=TImage.Create(Application);
        img.Picture.LoadFromFile(objParametrosDeEntrada.IMAGEM);
        Lista.Canvas.StretchDraw(Rect(30,30,780,1100),img.Picture.Graphic);


        sComando := 'SELECT distinct(PESO_UNITARIO) FROM ' + objParametrosDeEntrada.TABELA_PROCESSAMENTO
                  + ' WHERE CARTAO = "' + sNumeroDeCartao + '"'
                  + ' ORDER BY PESO_UNITARIO';
        objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

        stlListaDePesos.Clear;
        while not __queryMySQL_processamento__.Eof do
        begin
          stlListaDePesos.Add(StringReplace(__queryMySQL_processamento__.FieldByName('PESO_UNITARIO').AsString, ',', '.', [rfReplaceAll, rfIgnoreCase]));
          __queryMySQL_processamento__.Next;
        end; // END WHILE

        sComando := 'SELECT distinct(COD_CATEGORIA) FROM ' + objParametrosDeEntrada.TABELA_PROCESSAMENTO
                  + ' WHERE CARTAO = "' + sNumeroDeCartao + '"'
                  + ' ORDER BY COD_CATEGORIA';
        objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

        stlCategorias.Clear;
        while not __queryMySQL_processamento__.Eof do
        begin
          stlCategorias.Add(__queryMySQL_processamento__.FieldByName('COD_CATEGORIA').AsString);
          __queryMySQL_processamento__.Next;
        end; // END WHILE

        sComando := 'SELECT distinct(LOTE) FROM ' + objParametrosDeEntrada.TABELA_PROCESSAMENTO
                  + ' WHERE CARTAO = "' + sNumeroDeCartao + '"'
                  + ' ORDER BY LOTE';;
        objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

        stlListaDeLotes.Clear;
        while not __queryMySQL_processamento__.Eof do
        begin
          stlListaDeLotes.Add(__queryMySQL_processamento__.FieldByName('LOTE').AsString);
          __queryMySQL_processamento__.Next;
        end; //END WHILE


        Lista.Canvas.Font.Name := 'Arial';
        Lista.Canvas.Font.Size := 13;

        if StrToInt(objParametrosDeEntrada.PEDIDO_LOTE_MANUAL) = 0 then
          LISTA.Canvas.TextOut(480 , 50, FormatFloat(objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO, StrToInt(objParametrosDeEntrada.PEDIDO_LOTE)) + '/' + FormatDateTime('YYYY', Now()) )
        else
          LISTA.Canvas.TextOut(480 , 50, FormatFloat(objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO, StrToInt(objParametrosDeEntrada.PEDIDO_LOTE_MANUAL)) + '/' + FormatDateTime('YYYY', Now()));

        Lista.Canvas.Font.Size := 8;
        LISTA.Canvas.TextOut(670, 52 , objParametrosDeEntrada.DATA_POSTAGEM);

        sComando := 'SELECT * FROM ' + objParametrosDeEntrada.TABELA_PROCESSAMENTO
                  + ' where CARTAO = "' + sNumeroDeCartao + '"'
                  + ' group by N_CONTRATO ';
        objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

        Lista.Canvas.Font.Size := 7;
        LISTA.Canvas.TextOut(320, 095, 'BANCO BRADESCO');
        LISTA.Canvas.TextOut(80,  130, __queryMySQL_processamento__.FieldByName('N_CONTRATO').AsString);
        LISTA.Canvas.TextOut(340, 130, __queryMySQL_processamento__.FieldByName('CODIGO_ADM_CONTRATO').AsString);
        LISTA.Canvas.TextOut(600, 130, __queryMySQL_processamento__.FieldByName('CARTAO').AsString);

        LISTA.Canvas.TextOut(80,  158, 'SPM');
        LISTA.Canvas.TextOut(150, 158, 'SÃO PAULO');
        LISTA.Canvas.TextOut(320, 158, 'GCCAP 3 CTC JAGUARÉ/SPM');
        //LISTA.Canvas.TextOut(320, 158, 'GCCAP/CTC VILA MARIA');
        LISTA.Canvas.TextOut(600, 158, '00425791');
        //LISTA.Canvas.TextOut(600, 158, '72724064');
        LISTA.Canvas.TextOut(250, 183, 'FINGERPRINT GRAFICA LTDA');
        LISTA.Canvas.TextOut(600, 183, '72.945.587/0004-65');

        //====================================================================================
        //                                DESCONTOS
        //====================================================================================
        Lista.Canvas.Font.Size := 7;
        LISTA.Canvas.TextOut(120, 198, '94 - CÓD. 2D OBJ AUTOMAT COM CEPNET:');
        //====================================================================================

        //====================================================================================
        //                              PRÉ REQUISITOS
        //====================================================================================
        Lista.Canvas.Font.Size := 7;
        LISTA.Canvas.TextOut(410, 220, '- CEP/ENDEREÇO COMPLETO E CORRETO:');
        LISTA.Canvas.TextOut(410, 230, '- PLANO DE TRIAGEN/ BLOCAGEM:');
        LISTA.Canvas.TextOut(410, 240, '- CHANCELA DE FRANQUEAMENTO:');
        LISTA.Canvas.TextOut(410, 250, '- CÓDIGO CIF:');
        LISTA.Canvas.TextOut(410, 260, '- RPE E LP:');
        LISTA.Canvas.TextOut(410, 270, '- CEPNET EM OBJETO AUTOMATIZAVEL:');
        LISTA.Canvas.TextOut(410, 280, '- CARGA UNIFIZADA:');
        //====================================================================================

        //====================================================================================
        //                                DESCONTOS
        //====================================================================================
        Lista.Canvas.Font.Size := 5;
        LISTA.Canvas.TextOut(35, 211, 'CORREIOS - CARIMBO /ASSINATURA/MATRÍCULA VALIDAÇÃO DOS PRÉ-REQUISITOS E DESCONTO');
        //====================================================================================



        Lista.Canvas.Font.Size := 7;
        yDesloc := 0;
        for iContCategoria := 0 to stlCategorias.Count - 1 do
        begin

          if stlCategorias.Strings[iContCategoria] = '82015' then
            xDesloc := 0;

          if stlCategorias.Strings[iContCategoria] = '82023' then
            xDesloc := 240;

          if stlCategorias.Strings[iContCategoria] = '82031' then
            xDesloc := 480;

          iContLinhas  := 0;
          iAjusteLinha := 0;
          yDesloc      := 0;

          for iContPesoUnitario := 0 to stlListaDePesos.Count - 1 do
          begin

            sComando := 'SELECT count(PESO_UNITARIO) as qtde, sum(PESO_UNITARIO) as peso FROM ' + objParametrosDeEntrada.TABELA_PROCESSAMENTO
                        + ' where PESO_UNITARIO = ' + stlListaDePesos.Strings[iContPesoUnitario]
                        + '   AND CARTAO        = "' + sNumeroDeCartao + '"'
                        + '   AND COD_CATEGORIA = ' + stlCategorias.Strings[iContCategoria];
            objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

            IF __queryMySQL_processamento__.FieldByName('qtde').AsInteger > 0 THEN
            begin

              LISTA.Canvas.TextOut(55  + xDesloc ,363 + yDesloc + iAjusteLinha, stlListaDePesos.Strings[iContPesoUnitario]);
              LISTA.Canvas.TextOut(115 + xDesloc ,363 + yDesloc + iAjusteLinha, FormatFloat('#,##', __queryMySQL_processamento__.FieldByName('qtde').AsInteger));
              LISTA.Canvas.TextOut(195 + xDesloc ,363 + yDesloc + iAjusteLinha, FormatFloat('#,##0.00', __queryMySQL_processamento__.FieldByName('peso').AsFloat));

              yDesloc := yDesloc + 19;

              // Ajuste do deslocamento
              iContLinhas  := iContLinhas + 1;
              if iContLinhas >= 3 then
              begin
                iAjusteLinha := iAjusteLinha + 2;
                iContLinhas  := 0;
              end; // END IF

            end; // END IF

          end; // END FOE

          sComando := 'SELECT count(PESO_UNITARIO) as qtde, sum(PESO_UNITARIO) as peso FROM ' + objParametrosDeEntrada.TABELA_PROCESSAMENTO
                      + ' where COD_CATEGORIA = ' + stlCategorias.Strings[iContCategoria]
                      + '   AND CARTAO        = "' + sNumeroDeCartao + '"';
          objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

          LISTA.Canvas.TextOut(120 + xDesloc  ,835, FormatFloat('#,##',__queryMySQL_processamento__.FieldByName('qtde').AsInteger));
          LISTA.Canvas.TextOut(200 + xDesloc  ,835, FormatFloat('#,##0.00', __queryMySQL_processamento__.FieldByName('peso').AsFloat));

        end; // END FOR

        sComando := 'SELECT count(PESO_UNITARIO) as qtde, sum(PESO_UNITARIO) as peso FROM ' + objParametrosDeEntrada.TABELA_PROCESSAMENTO
                  + '   WHERE CARTAO = "' + sNumeroDeCartao + '"';
        objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

        LISTA.Canvas.TextOut(600, 855, FormatFloat('#,##', __queryMySQL_processamento__.FieldByName('qtde').AsInteger));
        LISTA.Canvas.TextOut(600, 875, FormatFloat('#,##0.00', __queryMySQL_processamento__.FieldByName('peso').AsFloat));

        (*Observaçoes *)
        Lista.Canvas.Font.Name := 'LUCIDA';
        Lista.Canvas.Font.Size := 6;
        LISTA.Canvas.TextOut(40 , 985, 'OBSERVAÇÕES: ' + objParametrosDeEntrada.OBSERVACOES);

        Lista.Canvas.Font.Size := 8;
        //=====================================

        //=====================================
        // IMPRIMINDO OS LOTES EM OBSERVAÇÕES
        //=====================================
        Lista.Canvas.Font.Size := 7;

        xDesloc := 0;
        yDesloc := 0;
        iLimiteDeLotesNaPagina := 91;

        iLimiteLotes := 0;

        for iContLotes := 0 to stlListaDeLotes.Count - 1 do
        begin

          IF iNumeroDeLotesNaPagina  >= iLimiteDeLotesNaPagina THEN
          BEGIN

            Lista.NewPage;
            img_PG2 := TImage.Create(Application);
            img_PG2.Picture.LoadFromFile(objParametrosDeEntrada.IMAGEM_PG2);
            Lista.Canvas.StretchDraw(Rect(30,30,780,1100),img_PG2.Picture.Graphic);

            iDeslocYLinhaExtra := 93;
            for iContLinhasExtrasOG2 := 0 to 68 do
            begin

              Lista.Canvas.Moveto(32  , iDeslocYLinhaExtra);
              Lista.Canvas.LineTo(778 , iDeslocYLinhaExtra);

              iDeslocYLinhaExtra := iDeslocYLinhaExtra + 13;

            end; // END FOR


            //================================
            //   CABECALHO NUMERO DA LISTA
            //================================
            Lista.Canvas.Font.Name := 'Arial';
            Lista.Canvas.Font.Size := 13;

            if StrToInt(objParametrosDeEntrada.PEDIDO_LOTE_MANUAL) = 0 then
              LISTA.Canvas.TextOut(480 , 50, FormatFloat(objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO, StrToInt(objParametrosDeEntrada.PEDIDO_LOTE)) + '/' + FormatDateTime('YYYY', Now()) )
            else
              LISTA.Canvas.TextOut(480 , 50, FormatFloat(objParametrosDeEntrada.FORMATACAO_LOTE_PEDIDO, StrToInt(objParametrosDeEntrada.PEDIDO_LOTE_MANUAL)) + '/' + FormatDateTime('YYYY', Now()));
            //=========================================================

            //================================
            //  CABECALHO DATA POSTAGEM
            //================================
            Lista.Canvas.Font.Size := 8;
            LISTA.Canvas.TextOut(670, 52 , objParametrosDeEntrada.DATA_POSTAGEM);
            //===================================================================

            Lista.Canvas.Font.Size := 7;

            iNumeroDeLotesNaPagina := 0;

            xDesloc                := 0;
            yDesloc                := 0;
            iLimiteLotes           := 0;
            yDeslocPg2             := -813;

            iLimiteDeLotesNaPagina := 804;

          end; // END IF

          if yDesloc = 0 then
          begin
            LISTA.Canvas.TextOut(93 + xDesloc, 894 + yDesloc + yDeslocPg2, stlListaDeLotes.Strings[iContLotes]);
            iLimiteColunas := 22; //29
          end
          else
          Begin
            LISTA.Canvas.TextOut(45 + xDesloc, 894 + yDesloc + yDeslocPg2, stlListaDeLotes.Strings[iContLotes]);
            iLimiteColunas := 23;
          end;

          xDesloc      := xDesloc      + 31;
          iLimiteLotes := iLimiteLotes + 1;

          if iLimiteLotes >= iLimiteColunas then
          begin
            //yDesloc      := yDesloc + 13;
            yDesloc      := yDesloc + 26;
            xDesloc      := 0;
            iLimiteLotes := 0;
          end;

          inc(iNumeroDeLotesNaPagina);

        end; // END FOR



      end;
      Lista.EndDoc;

      Lista.Preview;

      IF objParametrosDeEntrada.IMPRIMIR THEN
      for iContImpressoes := 0 to StrToInt(objParametrosDeEntrada.NUMERO_DE_IMPRESSOES) -1 do
        Lista.print;

  end;

  *}

end;

procedure TCore.ExcluirBase(NomeTabela: String);
var
  sComando : String;
  sBase    : string;
begin

  sBase := objString.getTermo(1, '.', NomeTabela);

  sComando := 'drop database ' + sBase;
  objStatusProcessamento := objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 1);
end;

procedure TCore.ExcluirTabela(NomeTabela: String);
var
  sComando : String;
  sTabela  : String;
begin

  sTabela := objString.getTermo(2, '.', NomeTabela);

  sComando := 'drop table ' + sTabela;
  objStatusProcessamento := objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 1);
end;



procedure TCore.StoredProcedure_Dropar(Nome: string; logBD:boolean=false; idprograma:integer=0);
var
  sSQL: string;
  sMensagem: string;
begin
  try
    sSQL := 'DROP PROCEDURE if exists ' + Nome;
    objConexao.Executar_SQL(__queryMySQL_processamento__, sSQL, 1);
  except
    on E:Exception do
    begin
      sMensagem := '  StoredProcedure_Dropar(' + Nome + ') - Excecao:' + E.Message + ' . SQL: ' + sSQL;
      objLogar.Logar(sMensagem);
    end;
  end;

end;

function TCore.StoredProcedure_Criar(Nome : string; scriptSQL: TStringList): boolean;
var
  bExecutou    : boolean;
  sMensagem    : string;
begin


  bExecutou := objConexao.Executar_SQL(__queryMySQL_processamento__, scriptSQL.Text, 1).status;

  if not bExecutou then
  begin
    sMensagem := '  StoredProcedure_Criar(' + Nome + ') - Não foi possível carregar a stored procedure para execução.';
    objLogar.Logar(sMensagem);
  end;

  result := bExecutou;
end;

procedure TCore.StoredProcedure_Executar(Nome: string; ComParametro:boolean=false; logBD:boolean=false; idprograma:integer=0);
var

  sSQL        : string;
  sMensagem   : string;
begin

  try
    (*
    if not Assigned(con) then
    begin
      con := TZConnection.Create(Application);
      con.HostName  := objConexao.getHostName;
      con.Database  := sNomeBase;
      con.User      := objConexao.getUser;
      con.Protocol  := objConexao.getProtocolo;
      con.Password  := objConexao.getPassword;
      con.Properties.Add('CLIENT_MULTI_STATEMENTS=1');
      con.Connected := True;
    end;

    if not Assigned(QP) then
      QP := TZQuery.Create(Application);

    QP.Connection := con;
    QP.SQL.Clear;
    *)

    sSQL := 'CALL '+ Nome;
    if not ComParametro then
      sSQL := sSQL + '()';

    objConexao.Executar_SQL(__queryMySQL_processamento__, sSQL, 1);

  except
    on E:Exception do
    begin
      sMensagem := '[ERRO] StoredProcedure_Executar('+Nome+') - Excecao:'+E.Message+' . SQL: '+sSQL;
      objLogar.Logar(sMensagem);
      ShowMessage(sMensagem);
    end;
  end;

//  objConexao.Executar_SQL(__queryMySQL_processamento__, sSQL, 1)

end;

function TCore.EnviarEmail(Assunto: string=''; Corpo: string=''): Boolean;
var
  sHost    : string;
  suser    : string;
  sFrom    : string;
  sTo      : string;
  sAssunto : string;
  sCorpo   : string;
  sAnexo   : string;
  sAplicacao: string;

begin

  sAplicacao := ExtractFileName(Application.ExeName);
  sAplicacao := StringReplace(sAplicacao, '.exe', '', [rfReplaceAll, rfIgnoreCase]);

  sHost    := objParametrosDeEntrada.eHost;
  suser    := objParametrosDeEntrada.eUser;
  sFrom    := objParametrosDeEntrada.eFrom;
  sTo      := objParametrosDeEntrada.eTo;
  sAssunto := 'Processamento - ' + sAplicacao + ' - ' + objFuncoesWin.GetVersaoDaAplicacao() + ' [PROCESSAMENTO: ' + objParametrosDeEntrada.PEDIDO_LOTE + ']';
  sAssunto := sAssunto + ' ' + Assunto;
  sCorpo   := Corpo;

  sAnexo := objLogar.getArquivoDeLog();

  //sAnexo := StringReplace(anexo, '"', '', [rfReplaceAll, rfIgnoreCase]);
  //sAnexo := StringReplace(anexo, '''', '', [rfReplaceAll, rfIgnoreCase]);

  try

    objEmail := TSMTPDelphi.create(sHost, suser);

    if objEmail.ConectarAoServidorSMTP() then
    begin
      if objEmail.AnexarArquivo(sAnexo) then
      begin

          if not (objEmail.EnviarEmail(sFrom, sTo, sAssunto, sCorpo)) then
            ShowMessage('ERRO AO ENVIAR O E-MAIL')
          else
          if not objEmail.DesconectarDoServidorSMTP() then
            ShowMessage('ERRO AO DESCONECTAR DO SERVIDOR');
      end
      else
        ShowMessage('ERRO AO ANEXAR O ARQUIVO');
    end
    else
      ShowMessage('ERRO AO CONECTAR AO SERVIDOR');

  except
    ShowMessage('NÃO FOI POSSIVEL ENVIAR O E-MAIL.');
  end;
end;

function Tcore.PesquisarLote(LOTE_PEDIDO : STRING; status : Integer): Boolean;
var
  sComando : string;
  iPedido  : Integer;
  sStauts  : string;
begin

  case status of
    0: sStauts := 'S';
    1: sStauts := 'N';
  end;

  objParametrosDeEntrada.PEDIDO_LOTE_TMP := LOTE_PEDIDO;

  sComando := ' SELECT RELATORIO_QTD FROM  ' + objParametrosDeEntrada.TABELA_LOTES_PEDIDOS
            + ' WHERE LOTE_PEDIDO = ' + LOTE_PEDIDO + ' AND VALIDO = "' + sStauts + '"';
  objStatusProcessamento := objConexao.Executar_SQL(__queryMySQL_processamento__, sComando, 2);

  objParametrosDeEntrada.stlRelatorioQTDE.Text := __queryMySQL_processamento__.FieldByName('RELATORIO_QTD').AsString;

  if __queryMySQL_processamento__.RecordCount > 0 then
    Result := True
  else
    Result := False;

end;

function TCORE.Extrair_Arquivo_7z(Arquivo, destino : String): integer;
Var
  sComando                  : String;
  sParametros               : String;
  __AplicativoCompactacao__ : String;

  iRetorno                  : Integer;
Begin

    destino := objString.AjustaPath(destino);

    sParametros := ' e ';

    IF StrToInt(objParametrosDeEntrada.ARQUITETURA_WINDOWS) = 32 THEN
      __AplicativoCompactacao__ := objParametrosDeEntrada.app_7z_32bits;

    IF StrToInt(objParametrosDeEntrada.ARQUITETURA_WINDOWS) = 64 THEN
      __AplicativoCompactacao__ := objParametrosDeEntrada.app_7z_64bits;

    sComando := __AplicativoCompactacao__ + sParametros + ' ' + Arquivo +  ' -y -o"' + destino + '"';

    iRetorno := objFuncoesWin.WinExecAndWait32(sComando);

    Result   := iRetorno;

End;

PROCEDURE TCORE.EXTRAIR_ARQUIVO(ARQUIVO_ORIGEM, PATH_DESTINO: String);
begin

  Extrair_Arquivo_7z(ARQUIVO_ORIGEM, PATH_DESTINO);

end;

PROCEDURE TCORE.COMPACTAR_ARQUIVO(ARQUIVO_ORIGEM, PATH_DESTINO: String; MOVER_ARQUIVO: Boolean = FALSE; ZIP: Boolean=false);
begin

  Compactar_Arquivo_7z(ARQUIVO_ORIGEM, PATH_DESTINO, MOVER_ARQUIVO, ZIP);

end;

function TCORE.Compactar_Arquivo_7z(Arquivo, destino : String; mover_arquivo: Boolean=false; ZIP: Boolean=false): integer;
Var
  sComando                  : String;
  sArquivoDestino           : String;
  sParametros               : String;
  __AplicativoCompactacao__ : String;

  iRetorno                  : Integer;
Begin

  destino     := objString.AjustaPath(destino);
  sParametros := ' a ';

  if ZIP then
  begin

    IF Pos('.csv', Arquivo) > 0 THEN
      sArquivoDestino := StringReplace(ExtractFileName(Arquivo), '.csv', '', [rfReplaceAll, rfIgnoreCase]) + '.zip'
    else
    IF Pos('.txt', Arquivo) > 0 THEN
      sArquivoDestino := StringReplace(ExtractFileName(Arquivo), '.txt', '', [rfReplaceAll, rfIgnoreCase]) + '.zip'
    else
    IF Pos('.CSV', Arquivo) > 0 THEN
      sArquivoDestino := StringReplace(ExtractFileName(Arquivo), '.CSV', '', [rfReplaceAll, rfIgnoreCase]) + '.ZIP'
    else
    IF Pos('.TXT', Arquivo) > 0 THEN
      sArquivoDestino := StringReplace(ExtractFileName(Arquivo), '.TXT', '', [rfReplaceAll, rfIgnoreCase]) + '.ZIP'
    else
      sArquivoDestino := ExtractFileName(Arquivo) + '.ZIP';

    sParametros     := sParametros + ' -tzip ';

  end
  else
  BEGIN

    IF Pos('.TXT', Arquivo) > 0 THEN
      sArquivoDestino := StringReplace(ExtractFileName(Arquivo), '.TXT', '', [rfReplaceAll, rfIgnoreCase]) + '.7Z'
    ELSE
      sArquivoDestino := ExtractFileName(Arquivo) + '.7Z';

  end;

    IF StrToInt(objParametrosDeEntrada.ARQUITETURA_WINDOWS) = 32 THEN
      __AplicativoCompactacao__ := objParametrosDeEntrada.app_7z_32bits;

    IF StrToInt(objParametrosDeEntrada.ARQUITETURA_WINDOWS) = 64 THEN
      __AplicativoCompactacao__ := objParametrosDeEntrada.app_7z_64bits;

    sComando := __AplicativoCompactacao__ + sParametros + ' "' + destino + sArquivoDestino + '" "' + Arquivo + '"';

    if mover_arquivo then
      sComando := sComando + ' -sdel';

    iRetorno := objFuncoesWin.WinExecAndWait32(sComando);

    Result   := iRetorno;

End;

end.
